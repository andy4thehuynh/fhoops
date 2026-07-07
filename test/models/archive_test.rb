require "test_helper"

class ArchiveTest < ActiveSupport::TestCase
  EXPORT_DIR = Rails.root.join("test/fixtures/files/exporter_sample")

  test "imports imessage-exporter txt output" do
    provision_tenant.switch do
      result = Archive.import(EXPORT_DIR)

      assert_equal 6, result[:imported]
      assert_equal 0, result[:skipped]
      assert_equal 2, Chat.count

      chat = Contact.find_by!(handle: "+15551234567").chat
      assert_equal 4, chat.messages.count

      first = chat.messages.chronological.first
      assert first.is_from_me
      assert_equal "Hey, are we still on for tacos tonight?", first.body
      assert_equal Time.zone.local(2023, 1, 5, 15, 23, 12), first.sent_at

      multiline = chat.messages.chronological.last
      assert_equal "Happy valentine's day!\nThis is a second line of the same message", multiline.body

      # body is non-deterministically encrypted, so it can't be queried —
      # decrypt and filter in Ruby.
      with_attachment = chat.messages.detect { |m| m.body == "Check out their new menu" }
      attachment = with_attachment.attachments.sole
      assert_equal "taco-menu.jpeg", attachment.filename
      assert_equal "image/jpeg", attachment.mime_type
      assert_equal "/Users/andy/exports/attachments/taco-menu.jpeg", attachment.path
    end
  end

  test "txt import is idempotent" do
    provision_tenant.switch do
      Archive.import(EXPORT_DIR)
      result = Archive.import(EXPORT_DIR)

      assert_equal 0, result[:imported]
      assert_equal 6, result[:skipped]
      assert_equal 6, Message.count
    end
  end

  test "read receipts and tapback noise are not part of the body" do
    provision_tenant.switch do
      Archive.import(EXPORT_DIR)
      reply = Message.all.detect { |m| m.body == "Absolutely! 7pm at the usual spot" }
      assert_not_nil reply
      assert_not reply.is_from_me
    end
  end

  test "imports a chat.db snapshot read-only and idempotently" do
    snapshot = build_chat_db_snapshot

    provision_tenant.switch do
      result = Archive.import(snapshot)
      assert_equal 2, result[:imported]

      contact = Contact.find_by!(handle: "+15557654321")
      messages = contact.chat.messages.chronological
      assert_equal [ "Snapshot says hi", "Sure does" ], messages.map(&:body)
      assert_equal [ false, true ], messages.map(&:is_from_me)
      assert_in_delta Time.utc(2023, 6, 1, 12, 0, 0).to_i, messages.first.sent_at.to_i, 1

      attachment = messages.second.attachments.sole
      assert_equal "IMG_0001.heic", attachment.filename

      rerun = Archive.import(snapshot)
      assert_equal 0, rerun[:imported]
      assert_equal 2, rerun[:skipped]
    end
  ensure
    FileUtils.rm_f(snapshot)
  end

  test "refuses the live chat.db" do
    live = Pathname(Dir.home).join("Library/Messages/chat.db")
    FileUtils.mkdir_p(live.dirname)
    FileUtils.touch(live)

    provision_tenant.switch do
      assert_raises Archive::LiveDatabaseError do
        Archive.import(live)
      end
    end
  ensure
    FileUtils.rm_f(live)
  end

  private
    APPLE_EPOCH_OFFSET = 978_307_200

    def build_chat_db_snapshot
      path = Rails.root.join("tmp", "chat_snapshot_#{SecureRandom.hex(4)}.db")
      db = SQLite3::Database.new(path.to_s)
      db.execute_batch(<<~SQL)
        CREATE TABLE handle (ROWID INTEGER PRIMARY KEY, id TEXT);
        CREATE TABLE chat (ROWID INTEGER PRIMARY KEY);
        CREATE TABLE chat_handle_join (chat_id INTEGER, handle_id INTEGER);
        CREATE TABLE message (ROWID INTEGER PRIMARY KEY, guid TEXT, text TEXT, is_from_me INTEGER, date INTEGER, service TEXT, handle_id INTEGER);
        CREATE TABLE chat_message_join (chat_id INTEGER, message_id INTEGER);
        CREATE TABLE attachment (ROWID INTEGER PRIMARY KEY, filename TEXT, mime_type TEXT, total_bytes INTEGER);
        CREATE TABLE message_attachment_join (message_id INTEGER, attachment_id INTEGER);

        INSERT INTO handle VALUES (1, '+15557654321');
        INSERT INTO chat VALUES (1);
        INSERT INTO chat_handle_join VALUES (1, 1);
      SQL

      first_ns = (Time.utc(2023, 6, 1, 12, 0, 0).to_i - APPLE_EPOCH_OFFSET) * 1_000_000_000
      second_ns = first_ns + 90 * 1_000_000_000
      db.execute("INSERT INTO message VALUES (1, 'guid-aaa', 'Snapshot says hi', 0, ?, 'iMessage', 1)", [ first_ns ])
      db.execute("INSERT INTO message VALUES (2, 'guid-bbb', 'Sure does', 1, ?, 'iMessage', 1)", [ second_ns ])
      db.execute_batch(<<~SQL)
        INSERT INTO chat_message_join VALUES (1, 1), (1, 2);
        INSERT INTO attachment VALUES (1, '~/Library/Messages/Attachments/ab/IMG_0001.heic', 'image/heic', 123456);
        INSERT INTO message_attachment_join VALUES (2, 1);
      SQL
      db.close

      path
    end
end
