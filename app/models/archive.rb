# Ingest for the message archive. The source of truth is produced outside
# this app — by imessage-exporter or by snapshotting chat.db — and is only
# ever read, never written. Import is idempotent: every message carries a
# stable guid, and a message already in the archive is skipped.
module Archive
  class LiveDatabaseError < StandardError; end

  class << self
    # source: a directory of imessage-exporter .txt files, or a snapshot
    # chat.db SQLite file. Runs against the currently switched tenant.
    def import(source)
      path = Pathname(source).expand_path
      raise ArgumentError, "No such file or directory: #{path}" unless path.exist?

      importer = path.directory? ? TextImport.new(path) : ChatDbImport.new(path)
      importer.run
    end

    # The single funnel every importer feeds. Returns :imported or :skipped.
    def record(handle:, guid:, body:, sent_at:, is_from_me:, service:, display_name: nil, attachments: [])
      return :skipped if Message.exists?(guid: guid)

      contact = Contact.find_or_create_by!(handle: handle) { |c| c.display_name = display_name }
      chat = Chat.find_or_create_by!(contact: contact)
      message = chat.messages.create!(guid: guid, body: body, sent_at: sent_at, is_from_me: is_from_me, service: service)
      attachments.each { |attachment| message.attachments.create!(**attachment) }

      :imported
    end
  end
end
