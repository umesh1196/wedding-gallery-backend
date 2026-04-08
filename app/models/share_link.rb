class ShareLink < ApplicationRecord
  PERMISSIONS = %w[view view_like view_download].freeze

  attr_accessor :raw_token

  belongs_to :wedding
  belongs_to :created_by, class_name: "GallerySession"
  has_many :gallery_sessions, dependent: :nullify

  validates :token_digest, presence: true, uniqueness: true
  validates :permissions, inclusion: { in: PERMISSIONS }
  validates :label, presence: true
  validates :expires_at, presence: true
  validate :created_by_matches_wedding

  scope :available, -> { where(revoked_at: nil) }

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.issue!(wedding:, created_by:, permissions:, label:, expires_at: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    share_link = create!(
      wedding: wedding,
      created_by: created_by,
      token_digest: digest_token(raw_token),
      permissions: permissions,
      label: label,
      expires_at: expires_at || wedding.expires_at
    )
    share_link.raw_token = raw_token
    share_link
  end

  def active?
    revoked_at.nil? && expires_at.present? && expires_at >= Time.current && !wedding.expired?
  end

  private

  def created_by_matches_wedding
    return if created_by.blank? || wedding.blank?
    return if created_by.wedding_id == wedding_id

    errors.add(:created_by, "must belong to the same wedding")
  end
end
