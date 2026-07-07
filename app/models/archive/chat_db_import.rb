# Reads a snapshot copy of chat.db. The database is opened read-only, and
# opening the live ~/Library/Messages/chat.db is refused outright — always
# import from a copy. Only 1:1 chats are imported (group chats are out of
# scope for v1).
class Archive::ChatDbImport
  APPLE_EPOCH = Time.utc(2001, 1, 1)

  def initialize(path)
    if path == Pathname(Dir.home).join("Library/Messages/chat.db").expand_path
      raise Archive::LiveDatabaseError, "Refusing to open the live chat.db — import from a snapshot copy"
    end

    @path = path
  end

  def run
    counts = Hash.new(0)

    source = SQLite3::Database.new(@path.to_s, readonly: true, results_as_hash: true)

    source.execute(MESSAGES_SQL).each do |row|
      body = row["text"].to_s
      next if body.blank? && attachments_for(source, row["rowid"]).empty?

      counts[Archive.record(
        handle: row["handle"],
        guid: row["guid"],
        body: body,
        sent_at: time_at(row["date"]),
        is_from_me: row["is_from_me"] == 1,
        service: row["service"] || "iMessage",
        attachments: attachments_for(source, row["rowid"])
      )] += 1
    end

    { imported: counts[:imported], skipped: counts[:skipped] }
  ensure
    source&.close
  end

  private
    MESSAGES_SQL = <<~SQL
      SELECT m.ROWID AS rowid, m.guid, m.text, m.is_from_me, m.date, m.service, h.id AS handle
      FROM message m
      JOIN chat_message_join cmj ON cmj.message_id = m.ROWID
      JOIN chat c ON c.ROWID = cmj.chat_id
      JOIN chat_handle_join chj ON chj.chat_id = c.ROWID
      JOIN handle h ON h.ROWID = chj.handle_id
      WHERE c.ROWID IN (SELECT chat_id FROM chat_handle_join GROUP BY chat_id HAVING COUNT(*) = 1)
      ORDER BY m.date
    SQL

    ATTACHMENTS_SQL = <<~SQL
      SELECT a.filename, a.mime_type, a.total_bytes
      FROM message_attachment_join maj
      JOIN attachment a ON a.ROWID = maj.attachment_id
      WHERE maj.message_id = ?
    SQL

    # Modern chat.db stores nanoseconds since 2001-01-01; ancient rows used
    # whole seconds.
    def time_at(apple_date)
      seconds = apple_date > 10_000_000_000 ? apple_date / 1_000_000_000.0 : apple_date
      APPLE_EPOCH + seconds
    end

    def attachments_for(source, message_rowid)
      @attachments ||= {}
      @attachments[message_rowid] ||= source.execute(ATTACHMENTS_SQL, [ message_rowid ]).map do |row|
        {
          filename: row["filename"] && File.basename(row["filename"]),
          mime_type: row["mime_type"],
          byte_size: row["total_bytes"],
          path: row["filename"]
        }
      end
    end
end
