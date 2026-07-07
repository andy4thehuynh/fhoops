class Message < TenantRecord
  belongs_to :chat
  has_many :attachments, dependent: :destroy

  encrypts :body, key_provider: Tenant::KeyProvider.new

  validates :guid, presence: true, uniqueness: true

  scope :chronological, -> { order(:sent_at, :id) }
  scope :reverse_chronological, -> { order(sent_at: :desc, id: :desc) }
  scope :before, ->(message) { where("(sent_at, id) < (?, ?)", message.sent_at, message.id) }
  scope :missing_embedding, -> { where("messages.id NOT IN (SELECT message_id FROM message_embeddings)") }

  # What gets embedded: the body, or the attachment names when there is no
  # text, so photo-only messages are still findable.
  def embedding_text
    body.presence || attachments.map(&:filename).join(", ")
  end

  def store_embedding!(vector)
    self.class.connection.execute(self.class.sanitize_sql_array(
      [ "INSERT OR REPLACE INTO message_embeddings (message_id, embedding) VALUES (?, ?)", id, vector.to_json ]
    ))
  end

  # Backfills every message lacking a vector. Batched, resumable and
  # idempotent: rerunning only touches what's still missing.
  def self.backfill_embeddings(&progress)
    count = 0
    missing_embedding.find_each(batch_size: 100) do |message|
      message.store_embedding!(Ollama.embed(message.embedding_text))
      count += 1
      progress&.call(count)
    end
    count
  end

  # Cosine KNN over sqlite-vec, returned nearest-first.
  def self.nearest(vector, limit: 10)
    ids = connection.select_values(sanitize_sql_array(
      [ "SELECT message_id FROM message_embeddings WHERE embedding MATCH ? AND k = ? ORDER BY distance", vector.to_json, limit ]
    ))
    includes(chat: :contact).where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end
