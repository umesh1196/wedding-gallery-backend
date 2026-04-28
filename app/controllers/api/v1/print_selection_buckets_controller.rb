module Api
  module V1
    class PrintSelectionBucketsController < BaseController
      def index
        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket_scope))
      end

      def create
        bucket = wedding.print_selection_buckets.new(
          bucket_params.merge(
            created_by_studio: current_studio,
            sort_order: next_sort_order
          )
        )
        bucket.save!

        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket), status: :created)
      end

      def show
        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket))
      end

      def photos
        render_success(PhotoBlueprint.render_as_hash(bucket_photos))
      end

      def update
        bucket.update!(bucket_params)
        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket))
      end

      def destroy
        if bucket.print_selection_photos.exists?
          return render_error("Bucket must be empty before deleting", status: :unprocessable_entity, code: "bucket_not_empty")
        end

        bucket.destroy!
        render_success({ id: bucket.id, deleted: true })
      end

      def lock
        bucket.update!(locked_at: Time.current)
        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket))
      end

      def unlock
        bucket.update!(locked_at: nil)
        render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket))
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def bucket_scope
        @bucket_scope ||= wedding.print_selection_buckets.ordered
      end

      def bucket
        @bucket ||= bucket_scope.find_by!(slug: params[:slug])
      end

      def bucket_params
        params.require(:print_selection_bucket).permit(:name, :slug, :selection_limit)
      end

      def next_sort_order
        wedding.print_selection_buckets.maximum(:sort_order).to_i + 1
      end

      def bucket_photos
        bucket.print_selection_photos.includes(:photo).map(&:photo).select { |photo| photo.processing_status == "ready" }
      end
    end
  end
end
