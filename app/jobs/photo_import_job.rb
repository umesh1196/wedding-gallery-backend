class PhotoImportJob < ApplicationJob
  queue_as :default

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.update!(ingestion_status: "uploading", ingestion_error: nil)

    raise "Missing source connection" if photo.studio_storage_connection.blank?

    source = PhotoSources.build(photo.studio_storage_connection)
    tempfile = source.stream_to_tempfile(key: photo.source_key)

    Storage::Service.new.upload_file(
      key: photo.original_key,
      file_path: tempfile.path,
      content_type: photo.mime_type
    )

    photo.update!(
      ingestion_status: "copied",
      ingested_at: Time.current,
      processing_status: "pending",
      ingestion_error: nil
    )
    if photo.upload_batch
      photo.upload_batch.increment!(:completed_files)
      photo.upload_batch.refresh_status!
    end

    JobDispatch.enqueue(PhotoProcessingJob, photo.id)
  rescue StandardError => e
    photo&.update!(ingestion_status: "failed", ingestion_error: e.message)
    if photo&.upload_batch
      photo.upload_batch.increment!(:failed_files)
      photo.upload_batch.refresh_status!
    end
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
