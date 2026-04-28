module Api
  module V1
    module Gallery
      class PrintSelectionBucketsController < BaseController
        def index
          render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket_scope))
        end

        def show
          render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket))
        end

        def photos
          records = bucket.print_selection_photos.includes(photo: :ceremony).limit(limit + 1).to_a
          has_more = records.size > limit
          records = records.first(limit)

          render_success(
            records.filter_map { |record| record.photo if record.photo.processing_status == "ready" }
                   .map { |photo| gallery_photo_payload(photo) },
            meta: { has_more: has_more }
          )
        end

        def add_photos
          return render_error("Print bucket is locked", status: :forbidden, code: "print_bucket_locked") if bucket.locked?

          ids = photo_ids
          photos = current_wedding.photos.ready.where(id: ids).index_by { |photo| photo.id.to_s }
          missing_ids = ids - photos.keys
          return render_error("One or more photos do not belong to this wedding", status: :unprocessable_entity, code: "photo_not_in_wedding") if missing_ids.any?

          existing_ids = bucket.print_selection_photos.where(photo_id: ids).pluck(:photo_id).map(&:to_s)
          new_ids = ids - existing_ids

          if bucket.selected_count + new_ids.size > bucket.selection_limit
            return render_error("Selection limit reached", status: :unprocessable_entity, code: "selection_limit_reached")
          end

          PrintSelectionPhoto.transaction do
            new_ids.each do |photo_id|
              bucket.print_selection_photos.create!(photo: photos.fetch(photo_id))
            end
          end

          render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket.reload))
        end

        def remove_photo
          return render_error("Print bucket is locked", status: :forbidden, code: "print_bucket_locked") if bucket.locked?

          bucket.print_selection_photos.find_by!(photo_id: params[:photo_id]).destroy!
          render_success(PrintSelectionBucketBlueprint.render_as_hash(bucket.reload))
        end

        private

        def bucket_scope
          @bucket_scope ||= current_wedding.print_selection_buckets.ordered
        end

        def bucket
          @bucket ||= bucket_scope.find_by!(slug: params[:slug])
        end

        def photo_ids
          parsed_body =
            begin
              request.raw_post.present? ? JSON.parse(request.raw_post) : {}
            rescue JSON::ParserError
              {}
            end

          raw_ids =
            params[:photo_ids] ||
            params.dig(:print_selection_bucket, :photo_ids) ||
            request.request_parameters["photo_ids"] ||
            request.request_parameters[:photo_ids] ||
            parsed_body["photo_ids"] ||
            parsed_body.dig("print_selection_bucket", "photo_ids")

          ids = Array(raw_ids).map(&:to_s).uniq
          raise ActionController::ParameterMissing, :photo_ids if ids.empty?

          ids
        end

        def limit
          requested = params[:limit].to_i
          return 60 if requested <= 0

          [ requested, 100 ].min
        end
      end
    end
  end
end
