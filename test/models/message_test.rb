require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "body round-trips through encryption" do
    provision_tenant.switch do
      message = create_message(body: "meet me at the tacos truck")
      assert_equal "meet me at the tacos truck", message.reload.body
    end
  end

  test "body and attachment path are unreadable in the raw database" do
    provision_tenant.switch do
      message = create_message(body: "the secret is guacamole")
      message.attachments.create!(filename: "photo.jpeg", mime_type: "image/jpeg", byte_size: 12, path: "/volumes/archive/photo.jpeg")

      raw_body = TenantRecord.lease_connection.select_value("SELECT body FROM messages WHERE id = #{message.id}")
      raw_path = TenantRecord.lease_connection.select_value("SELECT path FROM attachments LIMIT 1")

      assert_no_match(/guacamole/, raw_body)
      assert_no_match(/photo\.jpeg/, raw_path)
    end
  end

  test "encrypted attributes are unreachable without a switched tenant" do
    tenant = provision_tenant
    message = tenant.switch { create_message(body: "hello") }

    assert_raises ActiveRecord::Encryption::Errors::Configuration do
      message.body
    end
  end

  test "hosted tenants cannot decrypt each other's ciphertext" do
    with_deployment_mode("hosted") do
      alpha = provision_tenant
      beta = provision_tenant

      row = alpha.switch do
        create_message(body: "for alpha's eyes only")
        TenantRecord.lease_connection.select_all("SELECT * FROM messages").first
      end

      beta.switch do
        chat = Chat.create!(contact: Contact.create!(handle: "+15559990000"))
        row["chat_id"] = chat.id

        columns = row.keys.join(", ")
        placeholders = row.keys.map { "?" }.join(", ")
        TenantRecord.lease_connection.raw_connection.execute("INSERT INTO messages (#{columns}) VALUES (#{placeholders})", row.values)

        assert_raises ActiveRecord::Encryption::Errors::Decryption do
          Message.sole.body
        end
      end
    end
  end

  test "self_host mode encrypts with the host key, hosted with per-tenant keys" do
    one = provision_tenant
    two = provision_tenant

    assert_equal one.encryption_secret, two.encryption_secret

    with_deployment_mode("hosted") do
      assert_not_equal one.encryption_secret, two.encryption_secret
    end
  end

  private
    def create_message(body:)
      contact = Contact.create!(handle: "+15551230000")
      chat = Chat.create!(contact: contact)
      chat.messages.create!(guid: SecureRandom.uuid, body: body, is_from_me: false, service: "iMessage", sent_at: Time.current)
    end

    def with_deployment_mode(mode)
      previous, ENV["DEPLOYMENT_MODE"] = ENV["DEPLOYMENT_MODE"], mode
      yield
    ensure
      ENV["DEPLOYMENT_MODE"] = previous
    end
end
