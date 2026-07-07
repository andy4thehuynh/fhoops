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

    private
      def provisioned_tenants
        @provisioned_tenants ||= []
      end
  end
end
