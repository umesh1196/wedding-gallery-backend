class GallerySession < ApplicationRecord
  INACTIVITY_TIMEOUT = 24.hours
  ROLES = %w[guest family couple].freeze
  SHARE_PERMISSIONS = ShareLink::PERMISSIONS.freeze

  belongs_to :wedding
  belongs_to :share_link, optional: true
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :shortlists, dependent: :destroy
  has_many :download_requests, dependent: :destroy

  validates :session_token_digest, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :last_active_at, presence: true
  validates :permissions, inclusion: { in: SHARE_PERMISSIONS }, allow_nil: true
  validate :share_link_matches_wedding
  validate :permissions_match_share_link

  scope :available, -> { where(revoked_at: nil) }

  def self.issue_for!(wedding:, visitor_name: nil, role: "guest", ip: nil, user_agent: nil, share_link: nil, permissions: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    session = create!(
      wedding: wedding,
      session_token_digest: digest_token(raw_token),
      visitor_name: visitor_name,
      role: role,
      share_link: share_link,
      permissions: permissions,
      last_ip: ip,
      last_user_agent: user_agent,
      last_active_at: Time.current
    )

    [ session, raw_token ]
  end

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def expired?
    last_active_at < INACTIVITY_TIMEOUT.ago
  end

  def active?
    revoked_at.nil? && !expired?
  end

  def shared?
    share_link_id.present?
  end

  def allows_likes?
    !shared? || %w[view_like view_download].include?(permissions)
  end

  def allows_downloads?
    !shared? || permissions == "view_download"
  end

  def touch_activity!(ip: nil, user_agent: nil)
    update_columns(
      last_active_at: Time.current,
      last_ip: ip.presence || last_ip,
      last_user_agent: user_agent.presence || last_user_agent,
      updated_at: Time.current
    )
  end

  private

  def share_link_matches_wedding
    return if share_link.blank? || wedding.blank?
    return if share_link.wedding_id == wedding_id

    errors.add(:share_link, "must belong to the same wedding")
  end

  def permissions_match_share_link
    return if share_link.blank? && permissions.blank?
    return if share_link.present? && permissions == share_link.permissions

    errors.add(:permissions, "must match the linked share permissions")
  end
end
