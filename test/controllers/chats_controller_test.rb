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

  test "thread shows decrypted bubbles, mine on the right" do
    chat_id = @tenant.switch { Contact.find_by!(handle: "Mom").chat.id }

    get chat_path(chat_id)

    assert_response :success
    assert_select ".bubble-row", count: 2
    assert_select ".bubble-row.mine .bubble", text: /Will do, around lunch/
    assert_select ".bubble-row:not(.mine) .bubble", text: /Call me when you get a chance/
    assert_select ".bubble-time", minimum: 2
  end

  test "thread paginates from newest backwards" do
    chat_id = @tenant.switch do
      chat = Chat.create!(contact: Contact.create!(handle: "+15550001111"))
      60.times do |i|
        chat.messages.create!(guid: "page-#{i}", body: "message #{i}", is_from_me: i.even?,
          service: "iMessage", sent_at: 3.days.ago + i.minutes)
      end
      chat.id
    end

    get chat_path(chat_id)
    assert_select ".bubble", count: 50
    assert_match "message 59", response.body
    assert_no_match(/message 9</, response.body) # messages 0-9 belong to the earlier page
    assert_select ".load-earlier a", count: 1

    earliest_loaded = @tenant.switch { Message.all.detect { |m| m.body == "message 10" }.id }
    get chat_path(chat_id, before: earliest_loaded)
    assert_select ".bubble", count: 10
    assert_match "message 0", response.body
    assert_select ".load-earlier", count: 0
  end
end
