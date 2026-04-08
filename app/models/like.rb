class Like < ApplicationRecord
  belongs_to :photo
  belongs_to :gallery_session

  validates :photo_id, uniqueness: { scope: :gallery_session_id }
  validate :photo_belongs_to_session_wedding

  private

  def photo_belongs_to_session_wedding
    return if photo.blank? || gallery_session.blank?
    return if photo.wedding_id == gallery_session.wedding_id

    errors.add(:photo, "must belong to the session wedding")
  end
end
