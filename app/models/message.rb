class Message < TenantRecord
  belongs_to :chat
  has_many :attachments, dependent: :destroy

  encrypts :body, key_provider: Tenant::KeyProvider.new

  validates :guid, presence: true, uniqueness: true

  scope :chronological, -> { order(:sent_at, :id) }
  scope :reverse_chronological, -> { order(sent_at: :desc, id: :desc) }
  scope :before, ->(message) { where("(sent_at, id) < (?, ?)", message.sent_at, message.id) }
end
