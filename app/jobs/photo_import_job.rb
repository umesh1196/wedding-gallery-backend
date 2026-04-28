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

    tick_batch_counter(photo, :completed_files)
    JobDispatch.enqueue(PhotoProcessingJob, photo.id)
  rescue StandardError => e
    photo&.update!(ingestion_status: "failed", ingestion_error: e.message)
    tick_batch_counter(photo, :failed_files)
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  private

  # Atomically increment one counter on the batch and only call refresh_status!
  # when all files are accounted for. This avoids N redundant UPDATE calls on
  # large imports where hundreds of jobs complete in parallel.
  def tick_batch_counter(photo, counter)
    return unless photo&.upload_batch_id

    UploadBatch.update_counters(photo.upload_batch_id, counter => 1)
    batch = UploadBatch.find(photo.upload_batch_id)
    batch.refresh_status! if batch.accounted_files >= batch.total_files
  end
end
