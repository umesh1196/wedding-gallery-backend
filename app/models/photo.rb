class Photo < ApplicationRecord
  SOURCE_PROVIDERS = %w[gallery_storage backblaze_b2 cloudflare_r2].freeze
  INGESTION_STATUSES = %w[pending_import queued uploading copied failed].freeze
  PROCESSING_STATUSES = %w[pending processing ready failed].freeze
  FACE_RECOGNITION_STATUSES = %w[pending processing done failed skipped].freeze

  INGESTION_TRANSITIONS = {
    "pending_import" => %w[queued uploading],
    "queued"         => %w[uploading failed],
    "uploading"      => %w[copied failed],
    "copied"         => [],
    "failed"         => %w[queued]
  }.freeze

  PROCESSING_TRANSITIONS = {
    "pending"    => %w[processing],
    "processing" => %w[ready failed],
    "ready"      => [],
    "failed"     => %w[pending]
  }.freeze

  belongs_to :ceremony
  belongs_to :wedding
  belongs_to :studio_storage_connection, optional: true
  belongs_to :upload_batch, optional: true
  has_many :album_photos, dependent: :destroy
  has_many :albums, through: :album_photos
  has_many :print_selection_photos, dependent: :destroy
  has_many :print_selection_buckets, through: :print_selection_photos
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :shortlist_photos, dependent: :destroy
  has_many :person_photos, dependent: :destroy
  has_many :people, through: :person_photos

  validates :original_key, presence: true
  validates :file_extension, presence: true
  validates :source_provider, inclusion: { in: SOURCE_PROVIDERS }
  validates :ingestion_status, inclusion: { in: INGESTION_STATUSES }
  validates :processing_status, inclusion: { in: PROCESSING_STATUSES }
  validates :face_recognition_status, inclusion: { in: FACE_RECOGNITION_STATUSES }
  validate :ingestion_status_transition, if: -> { ingestion_status_changed? && persisted? }
  validate :processing_status_transition, if: -> { processing_status_changed? && persisted? }
  validate :wedding_matches_ceremony
  validate :unique_import_source, if: -> { source_key.present? && source_etag.present? }

  scope :ready, -> { where(processing_status: "ready") }
  scope :face_recognition_needed, -> { where(face_recognition_status: %w[pending failed], processing_status: "ready") }

  def urls
    PhotoUrlBuilder.new(self).urls
  end

  def ready?
    processing_status == "ready"
  end

  private

  def ingestion_status_transition
    from = ingestion_status_was
    to = ingestion_status
    allowed = INGESTION_TRANSITIONS.fetch(from, [])
    return if allowed.include?(to)

    errors.add(:ingestion_status, "cannot transition from '#{from}' to '#{to}'")
  end

  def processing_status_transition
    from = processing_status_was
    to = processing_status
    allowed = PROCESSING_TRANSITIONS.fetch(from, [])
    return if allowed.include?(to)

    errors.add(:processing_status, "cannot transition from '#{from}' to '#{to}'")
  end

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
