class GuestIdentity < ApplicationRecord
  belongs_to :wedding
  has_many :gallery_sessions, dependent: :nullify

  validates :token_digest, presence: true, uniqueness: true
  validates :normalized_visitor_name, uniqueness: { scope: :wedding_id }, allow_nil: true

  before_validation :normalize_visitor_name

  def self.issue_for!(wedding:, visitor_name: nil)
    normalized_name = normalize_name(visitor_name)

    identity =
      if normalized_name.present?
        find_or_initialize_by(wedding: wedding, normalized_visitor_name: normalized_name)
      else
        new(wedding: wedding)
      end

    raw_token = SecureRandom.urlsafe_base64(32)
    identity.token_digest = digest_token(raw_token)
    identity.visitor_name = visitor_name.presence || identity.visitor_name
    identity.save!

    [ identity, raw_token ]
  end

  def self.find_for_token(token, wedding:)
    return if token.blank?

    find_by(token_digest: digest_token(token), wedding: wedding)
  end

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.normalize_name(value)
    value.to_s.strip.squish.downcase.presence
  end

  private

  def normalize_visitor_name
    self.normalized_visitor_name = self.class.normalize_name(visitor_name)
  end
end
