class Contact < TenantRecord
  MAX_FAVORITES = 6

  has_one :chat, dependent: :destroy

  validates :handle, presence: true, uniqueness: true

  scope :favorites, -> { where(favorite: true).order(:favorite_position) }

  def display_name
    super.presence || handle
  end
end
