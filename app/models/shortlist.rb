class Shortlist < ApplicationRecord
  belongs_to :wedding
  belongs_to :gallery_session
  has_many :shortlist_photos, -> { order(:sort_order, :id) }, dependent: :destroy
  has_many :photos, through: :shortlist_photos

  validates :gallery_session_id, uniqueness: { scope: :wedding_id }
  validate :session_belongs_to_wedding

  def photo_count
    shortlist_photos.size
  end

  private

  def session_belongs_to_wedding
    return if gallery_session.blank? || wedding.blank?
    return if gallery_session.wedding_id == wedding_id

    errors.add(:gallery_session, "must belong to the shortlist wedding")
  end
end
