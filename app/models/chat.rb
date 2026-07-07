class Chat < TenantRecord
  belongs_to :contact
  has_many :messages, dependent: :destroy

  scope :by_recency, -> { joins(:messages).group(:id).order(Arel.sql("MAX(messages.sent_at) DESC")) }
  scope :matching, ->(query) {
    joins(:contact).where("contacts.display_name LIKE :q OR contacts.handle LIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }

  def last_message
    messages.order(:sent_at, :id).last
  end
end
