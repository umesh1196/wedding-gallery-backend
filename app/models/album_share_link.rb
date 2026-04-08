class AlbumShareLink < ApplicationRecord
  PERMISSIONS = %w[view view_like view_download].freeze

  attr_accessor :raw_token

  belongs_to :album
  belongs_to :created_by_studio, class_name: "Studio", optional: true
  belongs_to :created_by_gallery_session, class_name: "GallerySession", optional: true

  validates :token_digest, presence: true, uniqueness: true
  validates :permissions, inclusion: { in: PERMISSIONS }
  validate :single_owner_path
  validate :owner_matches_album

  delegate :ceremony, :wedding, to: :album

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.issue!(album:, permissions:, label:, expires_at: nil, created_by_studio: nil, created_by_gallery_session: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    share_link = create!(
      album: album,
      created_by_studio: created_by_studio,
      created_by_gallery_session: created_by_gallery_session,
      token_digest: digest_token(raw_token),
      permissions: permissions,
      label: label,
      expires_at: expires_at || album.wedding.expires_at
    )
    share_link.raw_token = raw_token
    share_link
  end

  def active?
    revoked_at.nil? && (expires_at.blank? || expires_at >= Time.current) && !wedding.expired?
  end

  private

  def single_owner_path
    owners = [ created_by_studio.present?, created_by_gallery_session.present? ].count(true)
    return if owners == 1

    errors.add(:base, "must have exactly one owner")
  end

  def owner_matches_album
    return unless errors[:base].blank?
    return if album.blank?
    return if album.owned_by_studio?(created_by_studio)
    return if album.owned_by_gallery_session?(created_by_gallery_session)

    errors.add(:base, "must match the album owner")
  end
end
