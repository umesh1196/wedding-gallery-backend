module PhotoUploads
  class PresignService
    def initialize(studio:, wedding:, ceremony:, files:, storage_service: Storage::Service.new)
      @studio = studio
      @wedding = wedding
      @ceremony = ceremony
      @files = files
      @storage_service = storage_service
    end

    def call
      batch = @studio.upload_batches.create!(
        ceremony: @ceremony,
        source_type: "direct_upload",
        total_files: @files.size
      )

      payload = @files.map do |file|
        FileMetadata.validate!(file)
        ext = FileMetadata.extension_for(file[:filename], file[:content_type])
        photo = @ceremony.photos.create!(
          id: SecureRandom.uuid,
          wedding: @wedding,
          upload_batch: batch,
          original_key: temporary_original_key(ext),
          source_provider: "gallery_storage",
          file_size_bytes: file[:byte_size],
          mime_type: file[:content_type],
          original_filename: file[:filename],
          file_extension: ext,
          sort_order: next_sort_order,
          ingestion_status: "uploading",
          processing_status: "pending"
        )

        photo.update_column(:original_key, original_key_for(photo.id, ext))

        {
          photo_id: photo.id,
          presigned_url: @storage_service.presigned_upload_url(key: photo.original_key, content_type: photo.mime_type),
          object_key: photo.original_key,
          headers: { "Content-Type" => photo.mime_type }
        }
      end

      { payload: payload, upload_batch_id: batch.id }
    end

    private

    def next_sort_order
      @ceremony.photos.maximum(:sort_order).to_i + 1
    end

    def temporary_original_key(ext)
      original_key_for(SecureRandom.uuid, ext)
    end

    def original_key_for(photo_id, ext)
      Storage::KeyBuilder.original(
        studio_id: @wedding.studio_id,
        wedding_id: @wedding.id,
        photo_id: photo_id,
        ext: ext
      )
    end
  end
end
