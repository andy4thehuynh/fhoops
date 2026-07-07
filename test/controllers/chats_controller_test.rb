require "test_helper"

class ChatsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = provision_tenant
    @tenant.switch do
      Archive.import(Rails.root.join("test/fixtures/files/exporter_sample"))
      Contact.find_by!(handle: "Mom").update!(favorite: true, favorite_position: 0)
    end
  end

  test "index lists chats by recency with decrypted snippets" do
    get root_path

    assert_response :success
    assert_select ".chat-row", count: 2
    assert_select ".chat-name", text: "Mom"
    assert_match "Happy valentine", response.body
  end

  test "index shows the favorites strip" do
    get root_path
    assert_select ".favorites .favorite-name", text: "Mom"
  end

  test "search filters the chat list by contact" do
    get root_path, params: { q: "Mom" }

    assert_select ".chat-row", count: 1
    assert_select ".chat-name", text: "Mom"
  end
end
