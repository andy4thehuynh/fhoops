class Contact < TenantRecord
  MAX_FAVORITES = 6

  has_one :chat, dependent: :destroy

  validates :handle, presence: true, uniqueness: true

  scope :favorites, -> { where(favorite: true).order(:favorite_position) }

  class FavoritesFull < StandardError; end

  def favorite!
    transaction do
      others = self.class.favorites.where.not(id: id)
      raise FavoritesFull if others.count >= MAX_FAVORITES

      update!(favorite: true, favorite_position: (others.maximum(:favorite_position) || -1) + 1)
    end
  end

  def unfavorite!
    update!(favorite: false, favorite_position: nil)
  end

  # Positions carry a unique index, so reordering goes in two passes:
  # park everyone on a temporary slot, then deal the final positions.
  def self.reorder_favorites(ordered_ids)
    ordered_ids = ordered_ids.map(&:to_i)

    transaction do
      contacts = favorites.where(id: ordered_ids).to_a
      contacts.each { |contact| contact.update_columns(favorite_position: -contact.id) }
      contacts.sort_by { |contact| ordered_ids.index(contact.id) }
        .each_with_index { |contact, position| contact.update_columns(favorite_position: position) }
    end
  end

  def display_name
    super.presence || handle
  end
end
