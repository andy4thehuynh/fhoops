require "test_helper"

class MessageEmbeddingTest < ActiveSupport::TestCase
  setup do
    stub_ollama
    @tenant = provision_tenant
  end

  test "backfill embeds only what's missing and is resumable" do
    @tenant.switch do
      chat = Chat.create!(contact: Contact.create!(handle: "+15550009999"))
      3.times { |i| chat.messages.create!(guid: "emb-#{i}", body: "note #{i}", service: "iMessage", sent_at: i.hours.ago) }

      assert_equal 3, Message.backfill_embeddings
      assert_equal 0, Message.missing_embedding.count

      chat.messages.create!(guid: "emb-late", body: "late arrival", service: "iMessage", sent_at: Time.current)
      assert_equal 1, Message.backfill_embeddings
    end
  end

  test "nearest returns semantically closest messages first" do
    @tenant.switch do
      chat = Chat.create!(contact: Contact.create!(handle: "+15550008888"))
      taco = chat.messages.create!(guid: "n-1", body: "taco night at seven", service: "iMessage", sent_at: 2.hours.ago)
      other = chat.messages.create!(guid: "n-2", body: "picking up the dry cleaning", service: "iMessage", sent_at: 1.hour.ago)
      Message.backfill_embeddings

      results = Message.nearest(Ollama.embed("where are the tacos"), limit: 2)

      assert_equal [ taco.id, other.id ], results.map(&:id)
    end
  end

  test "attachment-only messages embed their filenames" do
    @tenant.switch do
      chat = Chat.create!(contact: Contact.create!(handle: "+15550007777"))
      message = chat.messages.create!(guid: "att-1", body: "", service: "iMessage", sent_at: Time.current)
      message.attachments.create!(filename: "taco-photo.heic", mime_type: "image/heic", path: "/x/taco-photo.heic")

      assert_equal "taco-photo.heic", message.embedding_text
    end
  end
end
