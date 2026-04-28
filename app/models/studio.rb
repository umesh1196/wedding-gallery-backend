class Studio < ApplicationRecord
  has_secure_password
  has_many :weddings, dependent: :destroy
  has_many :print_selection_buckets, foreign_key: :created_by_studio_id
  has_many :studio_storage_connections, dependent: :destroy
  has_many :upload_batches, dependent: :destroy

  HEX_COLOR_FORMAT = /\A#(?:\h{3}|\h{6})\z/
  ALLOWED_FONTS = [
    "Inter",
    "Playfair Display",
    "Lora",
    "Cormorant Garamond",
    "Montserrat",
    "Poppins",
    "DM Sans"
  ].freeze

  before_validation :normalize_email
  before_validation :normalize_slug
  before_validation :generate_slug, if: :should_generate_slug?

  validates :email,       presence: true, uniqueness: { case_sensitive: false },
                          format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :studio_name, presence: true
  validates :slug,        presence: true, uniqueness: true
  validates :color_primary, format: { with: HEX_COLOR_FORMAT }
  validates :color_accent, format: { with: HEX_COLOR_FORMAT }
  validates :font_heading, inclusion: { in: ALLOWED_FONTS }
  validates :font_body, inclusion: { in: ALLOWED_FONTS }
  validates :watermark_opacity, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  private

  def normalize_email
    self.email = email.to_s.downcase.strip.presence
  end

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence if slug.present?
  end

  def should_generate_slug?
    slug.blank? && studio_name.present?
  end

  public

  def logo_asset_url
    asset_url_for(:logo_key, fallback: self[:logo_url])
  end

  def watermark_asset_url
    asset_url_for(:watermark_key, fallback: self[:watermark_url])
  end

  def generate_slug
    return if studio_name.blank?

    base = studio_name.parameterize
    candidate = base
    counter = 1

    while Studio.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def asset_url_for(key_attribute, fallback:)
    key = public_send(key_attribute)
    return fallback if key.blank?

    Storage::Service.new.presigned_download_url(key: key)
  rescue StandardError
    fallback
  end
end
