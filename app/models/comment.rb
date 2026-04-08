class Comment < ApplicationRecord
  belongs_to :photo, counter_cache: true
  belongs_to :gallery_session

  before_validation :normalize_body
  before_validation :snapshot_visitor_name

  validates :body, presence: true, length: { maximum: 500 }
  validate :gallery_session_matches_photo_wedding

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  private

  def normalize_body
    self.body = body.to_s.strip.presence
  end

  def snapshot_visitor_name
    self.visitor_name_snapshot = gallery_session&.visitor_name if visitor_name_snapshot.blank?
  end

  def gallery_session_matches_photo_wedding
    return if photo.blank? || gallery_session.blank?
    return if photo.wedding_id == gallery_session.wedding_id

    errors.add(:gallery_session, "must belong to the same wedding as the photo")
  end
end
