class UploadBatch < ApplicationRecord
  SOURCE_TYPES = %w[import direct_upload].freeze
  STATUSES = %w[in_progress completed partial].freeze

  belongs_to :ceremony
  belongs_to :studio
  has_many :photos, dependent: :nullify

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }

  def refresh_status!
    accounted = completed_files + failed_files + skipped_files
    new_status =
      if accounted >= total_files && failed_files.positive?
        "partial"
      elsif accounted >= total_files
        "completed"
      else
        "in_progress"
      end

    update!(status: new_status)
  end
end
