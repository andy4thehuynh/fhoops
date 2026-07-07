class Contact < TenantRecord
  has_one :chat, dependent: :destroy

  validates :handle, presence: true, uniqueness: true

  def display_name
    super.presence || handle
  end
end
