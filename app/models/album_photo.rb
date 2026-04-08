class AlbumPhoto < ApplicationRecord
  belongs_to :album, counter_cache: :photos_count
  belongs_to :photo

  validates :photo_id, uniqueness: { scope: :album_id }
  validate :photo_matches_album_ceremony

  private

  def photo_matches_album_ceremony
    return if album.blank? || photo.blank?
    return if photo.ceremony_id == album.ceremony_id

    errors.add(:photo, "must belong to the album ceremony")
  end
end
