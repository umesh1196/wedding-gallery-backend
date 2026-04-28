class PrintSelectionPhoto < ApplicationRecord
  belongs_to :print_selection_bucket, counter_cache: :selected_count
  belongs_to :photo

  validates :photo_id, uniqueness: { scope: :print_selection_bucket_id }
  validate :photo_belongs_to_bucket_wedding

  private

  def photo_belongs_to_bucket_wedding
    return if photo.blank? || print_selection_bucket.blank?
    return if photo.wedding_id == print_selection_bucket.wedding_id

    errors.add(:photo, "must belong to the same wedding")
  end
end
