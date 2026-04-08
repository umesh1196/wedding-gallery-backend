class Photo < ApplicationRecord
  SOURCE_PROVIDERS = %w[gallery_storage backblaze_b2 cloudflare_r2].freeze
  INGESTION_STATUSES = %w[pending_import queued uploading copied failed].freeze
  PROCESSING_STATUSES = %w[pending processing ready failed].freeze

  belongs_to :ceremony
  belongs_to :wedding
  belongs_to :studio_storage_connection, optional: true
  belongs_to :upload_batch, optional: true
  has_many :likes, dependent: :destroy
  has_many :shortlist_photos, dependent: :destroy

  validates :original_key, presence: true
  validates :file_extension, presence: true
  validates :source_provider, inclusion: { in: SOURCE_PROVIDERS }
  validates :ingestion_status, inclusion: { in: INGESTION_STATUSES }
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validate :wedding_matches_ceremony
  validate :unique_import_source, if: -> { source_key.present? && source_etag.present? }

  scope :ready, -> { where(processing_status: "ready") }

  def urls
    PhotoUrlBuilder.new(self).urls
  end

  private

  def wedding_matches_ceremony
    return if ceremony.blank? || wedding.blank?
    return if ceremony.wedding_id == wedding_id

    errors.add(:wedding, "must match the ceremony wedding")
  end

  def unique_import_source
    duplicate = self.class.where(
      ceremony_id: ceremony_id,
      source_provider: source_provider,
      source_bucket: source_bucket,
      source_key: source_key,
      source_etag: source_etag
    ).where.not(id: id)

    errors.add(:source_key, "has already been imported") if duplicate.exists?
  end
end
