require "test_helper"

class SearchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    stub_ollama
    @tenant = provision_tenant
    @tenant.switch do
      Archive.import(Rails.root.join("test/fixtures/files/exporter_sample"))
      Message.backfill_embeddings
    end
  end

  test "search returns matching conversations, keyword and semantic messages" do
    get search_path, params: { q: "tacos" }

    assert_response :success
    assert_select "h2", text: "Messages"
    assert_match "tacos tonight", response.body
    assert_select "h2", text: "Similar by meaning"
  end

  test "ask mode renders a cited answer with its sources" do
    get search_path, params: { q: "when are we meeting for tacos?", mode: "ask" }

    assert_response :success
    assert_select ".answer p", text: /7pm at the usual spot \[1\]/
    assert_select ".answer-sources li", minimum: 1
  end

  test "blank query renders the empty state" do
    get search_path
    assert_response :success
    assert_select ".empty"
  end
end
