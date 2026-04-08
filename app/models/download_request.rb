class DownloadRequest < ApplicationRecord
  SCOPE_TYPES = %w[ceremony shortlist full_gallery].freeze
  STATUSES = %w[queued processing ready failed expired].freeze
  EXPIRY_WINDOW = 24.hours

  belongs_to :wedding
  belongs_to :gallery_session
  belongs_to :ceremony, optional: true
  belongs_to :shortlist, optional: true

  validates :scope_type, inclusion: { in: SCOPE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :filename, presence: true
  validate :scope_reference_presence
  validate :scope_reference_wedding_matches

  scope :active, -> { where.not(status: "expired") }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def mark_expired!
    update!(status: "expired")
  end

  private

  def scope_reference_presence
    errors.add(:ceremony, "must exist for ceremony downloads") if scope_type == "ceremony" && ceremony.blank?
    errors.add(:shortlist, "must exist for shortlist downloads") if scope_type == "shortlist" && shortlist.blank?
  end

  def scope_reference_wedding_matches
    if ceremony.present? && ceremony.wedding_id != wedding_id
      errors.add(:ceremony, "must belong to the same wedding")
    end

    if shortlist.present? && shortlist.wedding_id != wedding_id
      errors.add(:shortlist, "must belong to the same wedding")
    end

    return if gallery_session.blank? || wedding.blank?
    return if gallery_session.wedding_id == wedding_id

    errors.add(:gallery_session, "must belong to the same wedding")
  end
end
