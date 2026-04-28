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

      # Phase 1: Fetch S3 metadata for all files BEFORE acquiring the DB lock.
      # Each head() call is a network round-trip — we must not hold a row lock during this.
      file_metadata = @files.map do |file|
        metadata = source.head(key: file.fetch(:source_key))
        { source_key: file.fetch(:source_key), s3: metadata }
      end

      # Phase 2: All DB writes under a single ceremony row lock so sort_order
      # assignments from concurrent requests don't collide.
      @ceremony.with_lock do
        batch = @studio.upload_batches.create!(
          ceremony: @ceremony,
          source_type: "import",
          total_files: @files.size
        )

        existing_imports = load_existing_import_keys
        base_sort = @ceremony.photos.maximum(:sort_order).to_i
        queued = []
        skipped_count = 0
        sort_offset = 0

        file_metadata.each do |entry|
          metadata = entry[:s3]
          ext = PhotoUploads::FileMetadata.extension_for(metadata[:filename], metadata[:content_type])

          if existing_imports.include?([ entry[:source_key], metadata[:etag] ])
            skipped_count += 1
            next
          end

          photo_id = SecureRandom.uuid
          key = original_key_for(photo_id, ext)

          photo = @ceremony.photos.create!(
            id: photo_id,
            wedding: @wedding,
            studio_storage_connection: @connection,
            upload_batch: batch,
            original_key: key,
            source_provider: @connection.provider,
            source_bucket: @connection.bucket,
            source_key: entry[:source_key],
            source_etag: metadata[:etag],
            file_size_bytes: metadata[:byte_size],
            mime_type: metadata[:content_type],
            original_filename: metadata[:filename],
            file_extension: ext,
            sort_order: base_sort + sort_offset + 1,
            ingestion_status: "queued",
            processing_status: "pending"
          )

          sort_offset += 1
          existing_imports << [ photo.source_key, photo.source_etag ]

          JobDispatch.enqueue(PhotoImportJob, photo.id)
          queued << photo
        end

        # Update skipped count and finalize status in two writes rather than N.
        UploadBatch.update_counters(batch.id, skipped_files: skipped_count) if skipped_count > 0
        batch.reload
        batch.refresh_status! if batch.accounted_files >= batch.total_files

        {
          photos: queued,
          queued_count: queued.size,
          skipped_count: skipped_count,
          upload_batch_id: batch.id
        }
      end
    end

    private

    # Single bulk query for all existing (source_key, etag) pairs for this ceremony
    # and connection — avoids one DB round-trip per file in the loop.
    def load_existing_import_keys
      @ceremony.photos
        .where(source_provider: @connection.provider, source_bucket: @connection.bucket)
        .where.not(source_key: nil)
        .pluck(:source_key, :source_etag)
        .to_set
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
