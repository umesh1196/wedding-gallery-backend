module PhotoImports
  class CreateService
    def initialize(studio:, wedding:, ceremony:, connection:, files:)
      @studio = studio
      @wedding = wedding
      @ceremony = ceremony
      @connection = connection
      @files = files
    end

    def call
      source = PhotoSources.build(@connection)
      queued = []
      skipped_count = 0
      batch = @studio.upload_batches.create!(
        ceremony: @ceremony,
        source_type: "import",
        total_files: @files.size
      )

      @files.each do |file|
        metadata = source.head(key: file.fetch(:source_key))
        ext = PhotoUploads::FileMetadata.extension_for(metadata[:filename], metadata[:content_type])

        if duplicate_import?(file.fetch(:source_key), metadata[:etag])
          skipped_count += 1
          batch.increment!(:skipped_files)
          batch.refresh_status!
          next
        end

        photo = @ceremony.photos.create!(
          id: SecureRandom.uuid,
          wedding: @wedding,
          studio_storage_connection: @connection,
          upload_batch: batch,
          original_key: temporary_original_key(ext),
          source_provider: @connection.provider,
          source_bucket: @connection.bucket,
          source_key: file.fetch(:source_key),
          source_etag: metadata[:etag],
          file_size_bytes: metadata[:byte_size],
          mime_type: metadata[:content_type],
          original_filename: metadata[:filename],
          file_extension: ext,
          sort_order: next_sort_order,
          ingestion_status: "queued",
          processing_status: "pending"
        )

        photo.update_column(:original_key, original_key_for(photo.id, ext))

        JobDispatch.enqueue(PhotoImportJob, photo.id)
        queued << photo
      end

      {
        photos: queued,
        queued_count: queued.size,
        skipped_count: skipped_count,
        upload_batch_id: batch.id
      }
    end

    private

    def duplicate_import?(source_key, etag)
      @ceremony.photos.find_by(
        source_provider: @connection.provider,
        source_bucket: @connection.bucket,
        source_key: source_key,
        source_etag: etag
      ).present?
    end

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
