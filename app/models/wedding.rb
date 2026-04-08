class Wedding < ApplicationRecord
  ALLOW_DOWNLOAD_OPTIONS = %w[none shortlist all].freeze

  attr_reader :password

  belongs_to :studio
  has_many :ceremonies, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :gallery_sessions, dependent: :destroy
  has_many :shortlists, dependent: :destroy
  has_many :download_requests, dependent: :destroy

  before_validation :normalize_slug
  before_validation :generate_slug, if: :should_generate_slug?
  before_validation :hash_password, if: -> { @password.present? }

  validates :couple_name, presence: true
  validates :expires_at, presence: true
  validates :slug, presence: true, uniqueness: { scope: :studio_id }
  validates :password_hash, presence: true
  validates :allow_download, inclusion: { in: ALLOW_DOWNLOAD_OPTIONS }

  def password=(raw_password)
    @password = raw_password
  end

  def authenticate(raw_password)
    return false if password_hash.blank? || raw_password.blank?

    BCrypt::Password.new(password_hash).is_password?(raw_password)
  end

  def expired?
    expires_at < Time.current || !is_active
  end

  def ceremony_count
    ceremonies.size
  end

  def hero_asset_url
    return hero_image_url if hero_image_key.blank?

    Storage::Service.new.presigned_download_url(key: hero_image_key)
  rescue StandardError
    hero_image_url
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence if slug.present?
  end

  def should_generate_slug?
    couple_name.present? && (slug.blank? || (will_save_change_to_couple_name? && !will_save_change_to_slug?))
  end

  def generate_slug
    base = couple_name.to_s.parameterize
    candidate = base
    counter = 1

    while self.class.where(studio_id: studio_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def hash_password
    self.password_hash = BCrypt::Password.create(@password)
  end
end
