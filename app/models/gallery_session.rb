class GallerySession < ApplicationRecord
  INACTIVITY_TIMEOUT = 24.hours
  ROLES = %w[guest family couple].freeze

  belongs_to :wedding
  has_many :likes, dependent: :destroy
  has_many :shortlists, dependent: :destroy

  validates :session_token_digest, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :last_active_at, presence: true

  scope :available, -> { where(revoked_at: nil) }

  def self.issue_for!(wedding:, visitor_name: nil, role: "guest", ip: nil, user_agent: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    session = create!(
      wedding: wedding,
      session_token_digest: digest_token(raw_token),
      visitor_name: visitor_name,
      role: role,
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

  def touch_activity!(ip: nil, user_agent: nil)
    update_columns(
      last_active_at: Time.current,
      last_ip: ip.presence || last_ip,
      last_user_agent: user_agent.presence || last_user_agent,
      updated_at: Time.current
    )
  end
end
