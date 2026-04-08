class Ceremony < ApplicationRecord
  belongs_to :wedding
  has_many :albums, dependent: :destroy
  has_many :photos, dependent: :destroy
  has_many :download_requests, dependent: :nullify
  has_many :upload_batches, dependent: :destroy

  before_validation :normalize_slug
  before_validation :generate_slug, if: :should_generate_slug?

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :wedding_id }
  validates :sort_order, presence: true

  def cover_asset_url
    return cover_image_url if cover_image_key.blank?

    Storage::Service.new.presigned_download_url(key: cover_image_key)
  rescue StandardError
    cover_image_url
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence if slug.present?
  end

  def should_generate_slug?
    name.present? && (slug.blank? || (will_save_change_to_name? && !will_save_change_to_slug?))
  end

  def generate_slug
    base = name.to_s.parameterize
    candidate = base
    counter = 1

    while self.class.where(wedding_id: wedding_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end
end
