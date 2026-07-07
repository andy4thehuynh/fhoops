ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Tenants provisioned through this helper get their database files
    # removed when the test finishes.
    def provision_tenant
      Tenant.provision("t#{SecureRandom.hex(4)}").tap { |tenant| provisioned_tenants << tenant }
    end

    teardown do
      provisioned_tenants.each do |tenant|
        path = tenant.database_path.to_s
        FileUtils.rm_f([ path, "#{path}-wal", "#{path}-shm" ])
      end
    end

    # Deterministic local stand-in for Ollama: "taco" texts embed along one
    # axis, everything else along another, and generation echoes a canned
    # answer. No network, no models.
    def stub_ollama
      stubs = Faraday::Adapter::Test::Stubs.new
      stubs.post("/api/embeddings") do |env|
        [ 200, { "Content-Type" => "application/json" },
          { "embedding" => stub_vector(::JSON.parse(env.body)["prompt"]) }.to_json ]
      end
      stubs.post("/api/generate") do |env|
        [ 200, { "Content-Type" => "application/json" },
          { "response" => "They said 7pm at the usual spot [1]." }.to_json ]
      end

      Ollama.connection = Faraday.new { |f| f.request :json; f.response :json; f.adapter :test, stubs }
    end

    def stub_vector(text)
      Array.new(768, 0.0).tap { |v| text.downcase.include?("taco") ? v[0] = 1.0 : v[1] = 1.0 }
    end

    teardown { Ollama.connection = nil }

    private
      def provisioned_tenants
        @provisioned_tenants ||= []
      end
  end
end
