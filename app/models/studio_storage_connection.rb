class StudioStorageConnection < ApplicationRecord
  PROVIDERS = %w[backblaze_b2 cloudflare_r2].freeze

  belongs_to :studio
  has_many :photos, dependent: :nullify

  validates :label, presence: true
  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :bucket, presence: true
  validates :access_key_ciphertext, presence: true
  validates :secret_key_ciphertext, presence: true
  validate :single_default_per_studio

  scope :active, -> { where(active: true) }

  def credentials
    {
      access_key_id: access_key_ciphertext,
      secret_access_key: secret_key_ciphertext
    }
  end

  def normalized_prefix(prefix)
    [ base_prefix, prefix ].compact.map { |value| value.to_s.gsub(%r{\A/+|/+\z}, "") }.reject(&:blank?).join("/")
      .yield_self { |value| value.present? ? "#{value}/" : "" }
  end

  private

  def single_default_per_studio
    return unless is_default?
    return if studio_id.blank?

    existing = self.class.where(studio_id: studio_id, is_default: true).where.not(id: id)
    errors.add(:is_default, "has already been taken") if existing.exists?
  end
end
