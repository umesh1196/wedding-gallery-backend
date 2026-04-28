class UploadBatch < ApplicationRecord
  SOURCE_TYPES = %w[import direct_upload].freeze
  STATUSES = %w[in_progress completed partial].freeze

  belongs_to :ceremony
  belongs_to :studio
  has_many :photos, dependent: :nullify

  validates :source_type, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }

  def accounted_files
    completed_files + failed_files + skipped_files
  end

  def refresh_status!
    new_status =
      if accounted_files >= total_files && failed_files.positive?
        "partial"
      elsif accounted_files >= total_files
        "completed"
      else
        "in_progress"
      end

    update!(status: new_status)
  end
end
