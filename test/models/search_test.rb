require "test_helper"

class SearchTest < ActiveSupport::TestCase
  setup do
    stub_ollama
    @tenant = provision_tenant
    @tenant.switch do
      Archive.import(Rails.root.join("test/fixtures/files/exporter_sample"))
      Message.backfill_embeddings
    end
  end

  test "keyword search decrypts and matches substrings, newest first" do
    @tenant.switch do
      results = Search.keyword("tacos")

      assert_equal 1, results.size
      assert_match(/tacos tonight/, results.first.body)
    end
  end

  test "keyword search honors its limit" do
    @tenant.switch do
      assert_equal 2, Search.keyword("l", limit: 2).size
    end
  end

  test "semantic search returns neighbors by meaning" do
    @tenant.switch do
      # The Ollama stub embeds "taco" texts along one axis and everything
      # else along another — same-axis queries must come back first.
      results = Search.semantic("any taco plans?")

      assert results.any?
      assert_match(/tacos/, results.first.body)
    end
  end

  test "semantic search degrades to empty when Ollama is down" do
    Ollama.connection = Faraday.new("http://127.0.0.1:1") { |f| f.response :raise_error }

    @tenant.switch do
      assert_equal [], Search.semantic("anything")
    end
  end

  test "ask returns a cited answer built from retrieved messages" do
    @tenant.switch do
      answer = Search.ask("what time are we meeting for tacos?")

      assert_match(/7pm.*\[1\]/, answer.text)
      assert answer.sources.any?
      assert_match(/tacos/, answer.sources.first.body)
    end
  end

  test "generation can be disabled without breaking retrieval" do
    previous, ENV["GEN_MODEL"] = ENV["GEN_MODEL"], ""
    assert_not Search.generation_enabled?
    @tenant.switch { assert Search.semantic("tacos").any? }
  ensure
    ENV["GEN_MODEL"] = previous
  end
end
