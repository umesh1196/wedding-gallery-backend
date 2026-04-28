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
      # Validate all files before acquiring the lock so we fail fast on bad input
      @files.each { |file| FileMetadata.validate!(file) }

      # Lock the ceremony row to prevent concurrent requests from racing on sort_order.
      # presigned_url generation is pure local HMAC signing — no network call — so it's
      # safe to do inside the lock.
      @ceremony.with_lock do
        batch = @studio.upload_batches.create!(
          ceremony: @ceremony,
          source_type: "direct_upload",
          total_files: @files.size
        )

        base_sort = @ceremony.photos.maximum(:sort_order).to_i

        payload = @files.each_with_index.map do |file, index|
          ext = FileMetadata.extension_for(file[:filename], file[:content_type])
          photo_id = SecureRandom.uuid
          key = original_key_for(photo_id, ext)

          photo = @ceremony.photos.create!(
            id: photo_id,
            wedding: @wedding,
            upload_batch: batch,
            original_key: key,
            source_provider: "gallery_storage",
            file_size_bytes: file[:byte_size],
            mime_type: file[:content_type],
            original_filename: file[:filename],
            file_extension: ext,
            sort_order: base_sort + index + 1,
            ingestion_status: "uploading",
            processing_status: "pending"
          )

          {
            photo_id: photo.id,
            presigned_url: @storage_service.presigned_upload_url(key: photo.original_key, content_type: photo.mime_type),
            object_key: photo.original_key,
            headers: { "Content-Type" => photo.mime_type }
          }
        end

        { payload: payload, upload_batch_id: batch.id }
      end
    end

    private

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
