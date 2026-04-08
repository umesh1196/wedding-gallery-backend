class ShortlistPhoto < ApplicationRecord
  belongs_to :shortlist
  belongs_to :photo

  validates :photo_id, uniqueness: { scope: :shortlist_id }
  validate :photo_belongs_to_shortlist_wedding

  private

  def photo_belongs_to_shortlist_wedding
    return if shortlist.blank? || photo.blank?
    return if shortlist.wedding_id == photo.wedding_id

    errors.add(:photo, "must belong to the shortlist wedding")
  end
end
