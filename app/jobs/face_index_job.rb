class FaceIndexJob < ApplicationJob
  queue_as :default

  # Two call signatures:
  #   FaceIndexJob.perform_later(photo_id)              — single photo, from PhotoProcessingJob
  #   FaceIndexJob.perform_later(wedding_id: wid)       — wedding batch, from admin trigger
  def perform(photo_id = nil, wedding_id: nil)
    if wedding_id.present?
      perform_for_wedding(wedding_id)
    elsif photo_id.present?
      perform_for_photo(photo_id)
    end
  end

  private

  def perform_for_wedding(wedding_id)
    photos = Photo.where(wedding_id: wedding_id).face_recognition_needed.order(:created_at)
    Rails.logger.info("[FaceIndexJob] Processing #{photos.count} photos for wedding #{wedding_id}")

    photos.each do |photo|
      begin
        run_service_for(photo)
      rescue => e
        Rails.logger.error("[FaceIndexJob] Photo #{photo.id} failed: #{e.message}")
        photo.update_columns(
          face_recognition_status: "failed",
          face_recognition_error: e.message.truncate(500)
        )
      end
    end
  end

  def perform_for_photo(photo_id)
    photo = Photo.find(photo_id)
    return unless photo.processing_status == "ready"
    return if photo.face_recognition_status == "done"

    run_service_for(photo)
  rescue => e
    Rails.logger.error("[FaceIndexJob] Photo #{photo_id} failed: #{e.message}")
    photo&.update_columns(
      face_recognition_status: "failed",
      face_recognition_error: e.message.truncate(500)
    )
  end

  def run_service_for(photo)
    photo.update_columns(face_recognition_status: "processing", face_recognition_error: nil)
    FaceService::IndexPhotoService.new(photo).call
  end
end
