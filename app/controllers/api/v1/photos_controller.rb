module Api
  module V1
    class PhotosController < BaseController
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
        render_success(PhotoImports::DiscoverService.new(connection: source_connection, prefix: params[:prefix]).call)
      end

      def import
        result = PhotoImports::CreateService.new(
          studio: current_studio,
          wedding: wedding,
          ceremony: ceremony,
          connection: source_connection,
          files: normalized_files
        ).call

        status = result[:photos].any? ? :created : :ok
        render_success(
          PhotoBlueprint.render_as_hash(result[:photos]),
          status: status,
          meta: {
            queued_count: result[:queued_count],
            skipped_count: result[:skipped_count],
            upload_batch_id: result[:upload_batch_id]
          }
        )
      end

      def presign
        result = PhotoUploads::PresignService.new(
          studio: current_studio,
          wedding: wedding,
          ceremony: ceremony,
          files: normalized_files
        ).call

        render_success(result[:payload], status: :created, meta: { upload_batch_id: result[:upload_batch_id] })
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
        PhotoUploads::FileMetadata.validate!(file)
      end

      def file_extension_for(filename, content_type)
        PhotoUploads::FileMetadata.extension_for(filename, content_type)
      end

      def next_sort_order
        ceremony.photos.maximum(:sort_order).to_i + 1
      end

      def normalized_files
        PhotoUploads::FileMetadata.normalize(params.require(:files))
      end
    end
  end
end
