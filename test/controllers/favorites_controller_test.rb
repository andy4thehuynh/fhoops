require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = provision_tenant
    @contact_id, @chat_id = @tenant.switch do
      contact = Contact.create!(handle: "+15553334444")
      chat = Chat.create!(contact: contact)
      chat.messages.create!(guid: "fav-1", body: "hi", service: "iMessage", sent_at: Time.current)
      [ contact.id, chat.id ]
    end
  end

  test "pin and unpin from the thread screen" do
    post favorites_path, params: { contact_id: @contact_id }
    assert_redirected_to root_path
    assert @tenant.switch { Contact.find(@contact_id).favorite }

    delete favorite_path(@contact_id)
    assert_not @tenant.switch { Contact.find(@contact_id).favorite }
  end

  test "pinning past the cap redirects with an alert" do
    @tenant.switch { 6.times { |i| Contact.create!(handle: "+1555999000#{i}").favorite! } }

    post favorites_path, params: { contact_id: @contact_id }

    assert_redirected_to root_path
    assert_match(/Favorites are full/, flash[:alert])
  end

  test "reorder endpoint persists drag order" do
    ids = @tenant.switch { 3.times.map { |i| Contact.create!(handle: "+1555888000#{i}").tap(&:favorite!).id } }

    patch favorites_order_path, params: { contact_ids: [ ids[1], ids[2], ids[0] ] }, as: :json

    assert_response :no_content
    assert_equal [ ids[1], ids[2], ids[0] ], @tenant.switch { Contact.favorites.pluck(:id) }
  end

  test "the thread header shows the pin state" do
    get chat_path(@chat_id)
    assert_select "button.star", text: "☆"

    post favorites_path, params: { contact_id: @contact_id }
    get chat_path(@chat_id)
    assert_select "button.star", text: "★"
  end
end
