require "test_helper"

class HostedModeTest < ActionDispatch::IntegrationTest
  setup do
    ENV["DEPLOYMENT_MODE"] = "hosted"
    @alpha = provision_tenant
    @beta = provision_tenant

    @alpha.switch do
      chat = Chat.create!(contact: Contact.create!(handle: "+15551000001", display_name: "Alpha Friend"))
      chat.messages.create!(guid: "a-1", body: "alpha's message", service: "iMessage", sent_at: Time.current)
    end
  end

  teardown do
    ENV.delete("DEPLOYMENT_MODE")
  end

  test "requests are served from the subdomain's tenant" do
    host! "#{@alpha.name}.ikeep.test"
    get root_path
    assert_response :success
    assert_match "Alpha Friend", response.body

    host! "#{@beta.name}.ikeep.test"
    get root_path
    assert_response :success
    assert_no_match "Alpha Friend", response.body
  end

  test "unknown subdomains 404" do
    host! "nobody.ikeep.test"
    get root_path
    assert_response :not_found
  end
end
