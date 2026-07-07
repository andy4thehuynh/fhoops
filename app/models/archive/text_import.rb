# Reads a directory of imessage-exporter txt output — one file per
# conversation, named after the contact's handle. The txt format carries no
# message guids, so we derive a stable one from the message's own identity;
# re-importing the same export is a no-op.
class Archive::TextImport
  TIMESTAMP = /\A[A-Z][a-z]{2} \d{1,2}, \d{4}\s+\d{1,2}:\d{2}:\d{2}\s?[AP]M(\s*\(.*\))?\z/
  METADATA = /\A(Read by |Delivered|Edited |Tapbacks:|This message responded to an earlier message)/

  def initialize(directory)
    @directory = directory
  end

  def run
    counts = Hash.new(0)

    Dir[@directory.join("*.txt").to_s].sort.each do |file|
      handle = File.basename(file, ".txt")

      each_message(File.read(file)) do |sent_at, sender, body, attachment_paths|
        counts[Archive.record(
          handle: handle,
          guid: derived_guid(handle, sent_at, sender, body),
          body: body,
          sent_at: sent_at,
          is_from_me: sender == "Me",
          service: "iMessage",
          attachments: attachment_paths.map { |path| attachment_for(path) }
        )] += 1
      end
    end

    { imported: counts[:imported], skipped: counts[:skipped] }
  end

  private
    def each_message(text)
      text.split(/\n{2,}/).each do |block|
        lines = block.strip.lines.map(&:chomp)
        next unless lines.first&.match?(TIMESTAMP)

        sent_at = parse_timestamp(lines.shift)
        sender = lines.shift
        attachment_paths, content = lines.reject { |line| line.match?(METADATA) }
          .partition { |line| line.start_with?("/") && File.extname(line).present? }
        body = content.join("\n")

        yield sent_at, sender, body, attachment_paths if sender
      end
    end

    def parse_timestamp(line)
      Time.zone.strptime(line.sub(/\s*\(.*\)\z/, "").squeeze(" "), "%b %d, %Y %I:%M:%S %p")
    end

    def derived_guid(handle, sent_at, sender, body)
      "txt-#{Digest::SHA256.hexdigest([ handle, sent_at.utc.iso8601, sender, body ].join("\x1F"))}"
    end

    def attachment_for(path)
      {
        filename: File.basename(path),
        mime_type: Marcel::MimeType.for(name: path),
        byte_size: File.size?(path),
        path: path
      }
    end
end
