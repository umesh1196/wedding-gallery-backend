module Api
  module V1
    class PhotosController < BaseController
      MAX_FILES_PER_REQUEST = 50
      MAX_FILE_SIZE = 30.megabytes
      ALLOWED_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif].freeze

      def index
        photos = ceremony.photos.order(:sort_order)
        photos = if params[:processing_status].present?
          photos.where(processing_status: params[:processing_status])
        else
          photos.where(processing_status: "ready")
        end

        render_success(PhotoBlueprint.render_as_hash(photos))
      end

      def discover_import
        conn = source_connection
        source = PhotoSources.build(conn)
        prefix = conn.normalized_prefix(params[:prefix])
        files = source.list(prefix: prefix)

        render_success(
          {
            connection_id: conn.id,
            provider: conn.provider,
            bucket: conn.bucket,
            prefix: prefix,
            files: files
          }
        )
      end

      def import
        conn = source_connection
        source = PhotoSources.build(conn)
        queued = []
        skipped_count = 0
        files = normalized_files
        batch = current_studio.upload_batches.create!(
          ceremony: ceremony,
          source_type: "import",
          total_files: files.size
        )

        files.each do |file|
          metadata = source.head(key: file.fetch(:source_key))
          ext = file_extension_for(metadata[:filename], metadata[:content_type])

          existing = ceremony.photos.find_by(
            source_provider: conn.provider,
            source_bucket: conn.bucket,
            source_key: file.fetch(:source_key),
            source_etag: metadata[:etag]
          )

          if existing
            skipped_count += 1
            batch.increment!(:skipped_files)
            batch.refresh_status!
            next
          end

          photo = ceremony.photos.create!(
            id: SecureRandom.uuid,
            wedding: wedding,
            studio_storage_connection: conn,
            upload_batch: batch,
            original_key: Storage::KeyBuilder.original(
              studio_id: wedding.studio_id,
              wedding_id: wedding.id,
              photo_id: SecureRandom.uuid,
              ext: ext
            ),
            source_provider: conn.provider,
            source_bucket: conn.bucket,
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

          # Keep the storage path stable and photo-id based after the record exists.
          photo.update_column(
            :original_key,
            Storage::KeyBuilder.original(
              studio_id: wedding.studio_id,
              wedding_id: wedding.id,
              photo_id: photo.id,
              ext: ext
            )
          )

          JobDispatch.enqueue(PhotoImportJob, photo.id)
          queued << photo
        end

        status = queued.any? ? :created : :ok
        render_success(
          PhotoBlueprint.render_as_hash(queued),
          status: status,
          meta: { queued_count: queued.size, skipped_count: skipped_count, upload_batch_id: batch.id }
        )
      end

      def presign
        service = Storage::Service.new
        files = normalized_files
        batch = current_studio.upload_batches.create!(
          ceremony: ceremony,
          source_type: "direct_upload",
          total_files: files.size
        )
        payload = files.map do |file|
          validate_upload_metadata!(file)
          ext = file_extension_for(file[:filename], file[:content_type])
          photo = ceremony.photos.create!(
            id: SecureRandom.uuid,
            wedding: wedding,
            upload_batch: batch,
            original_key: Storage::KeyBuilder.original(
              studio_id: wedding.studio_id,
              wedding_id: wedding.id,
              photo_id: SecureRandom.uuid,
              ext: ext
            ),
            source_provider: "gallery_storage",
            file_size_bytes: file[:byte_size],
            mime_type: file[:content_type],
            original_filename: file[:filename],
            file_extension: ext,
            sort_order: next_sort_order,
            ingestion_status: "uploading",
            processing_status: "pending"
          )

          photo.update_column(
            :original_key,
            Storage::KeyBuilder.original(
              studio_id: wedding.studio_id,
              wedding_id: wedding.id,
              photo_id: photo.id,
              ext: ext
            )
          )

          {
            photo_id: photo.id,
            presigned_url: service.presigned_upload_url(key: photo.original_key, content_type: photo.mime_type),
            object_key: photo.original_key,
            headers: { "Content-Type" => photo.mime_type }
          }
        end

        render_success(payload, status: :created, meta: { upload_batch_id: batch.id })
      end

      def confirm
        service = Storage::Service.new
        raise ActiveRecord::RecordNotFound, "Photo not found" unless service.exists?(key: photo.original_key)

        photo.update!(ingestion_status: "copied", ingested_at: Time.current, ingestion_error: nil)
        JobDispatch.enqueue(PhotoProcessingJob, photo.id)

        render_success(PhotoBlueprint.render_as_hash(photo))
      end

      def retry_import
        if photo.ingestion_status != "failed"
          return render_error("Photo import is not retryable", status: :unprocessable_entity, code: "validation_error")
        end

        photo.update!(ingestion_status: "queued", ingestion_error: nil)
        JobDispatch.enqueue(PhotoImportJob, photo.id)
        render_success(PhotoBlueprint.render_as_hash(photo))
      end

      def retry_processing
        if photo.processing_status != "failed"
          return render_error("Photo processing is not retryable", status: :unprocessable_entity, code: "validation_error")
        end

        photo.update!(processing_status: "pending", processing_error: nil)
        JobDispatch.enqueue(PhotoProcessingJob, photo.id)
        render_success(PhotoBlueprint.render_as_hash(photo))
      end

      def destroy
        keys = [ photo.original_key, photo.thumbnail_key ].compact
        photo.destroy!
        JobDispatch.enqueue(StorageCleanupJob, keys)
        render_success({ id: params[:id], deleted: true })
      end

      def reorder
        order = Array(params[:order]).map(&:to_s)
        photos_by_id = ceremony.photos.where(id: order).index_by { |record| record.id.to_s }
        missing_ids = order - photos_by_id.keys

        raise ActiveRecord::RecordNotFound, "Couldn't find Photo with provided ids" if missing_ids.any?

        Photo.transaction do
          order.each_with_index do |id, index|
            photos_by_id.fetch(id).update_columns(sort_order: index, updated_at: Time.current)
          end
        end

        render_success(PhotoBlueprint.render_as_hash(ceremony.photos.order(:sort_order)))
      end

      def set_cover
        photo_ceremony = photo.ceremony

        Photo.transaction do
          photo_ceremony.photos.where(is_cover: true).where.not(id: photo.id).update_all(is_cover: false, updated_at: Time.current)
          photo.update!(is_cover: true)
        end

        render_success(PhotoBlueprint.render_as_hash(photo))
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def ceremony
        @ceremony ||= wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
      end

      def source_connection
        connection_scope = current_studio.studio_storage_connections.active
        if params[:connection_id].present?
          connection_scope.find(params[:connection_id])
        else
          connection_scope.find_by!(is_default: true)
        end
      end

      def photo
        @photo ||= Photo.joins(:wedding).where(weddings: { studio_id: current_studio.id }).find(params[:id])
      end

      def validate_upload_metadata!(file)
        content_type = file[:content_type].to_s
        byte_size = file[:byte_size].to_i

        raise ActionController::ParameterMissing, "files" if file[:filename].blank?
        raise ArgumentError, "Unsupported file type" unless ALLOWED_CONTENT_TYPES.include?(content_type)
        raise ArgumentError, "File size must be less than 30MB" unless byte_size.positive? && byte_size <= MAX_FILE_SIZE
      end

      def file_extension_for(filename, content_type)
        ext = File.extname(filename.to_s).delete(".").downcase
        return ext if ext.present?

        Rack::Mime::MIME_TYPES.invert.fetch(content_type.to_s, ".jpg").delete(".")
      end

      def next_sort_order
        ceremony.photos.maximum(:sort_order).to_i + 1
      end

      def normalized_files
        Array(params.require(:files)).first(MAX_FILES_PER_REQUEST).map do |file|
          file.respond_to?(:to_unsafe_h) ? file.to_unsafe_h.with_indifferent_access : file.to_h.with_indifferent_access
        end
      end
    end
  end
end
