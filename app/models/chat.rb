class Chat < TenantRecord
  belongs_to :contact
  has_many :messages, dependent: :destroy

  scope :by_recency, -> { joins(:messages).group(:id).order(Arel.sql("MAX(messages.sent_at) DESC")) }

  def last_message
    messages.order(:sent_at).last
  end
end
