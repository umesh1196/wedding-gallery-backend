module Api
  module V1
    module Gallery
      class LikesController < BaseController
        before_action :ensure_likes_allowed!, only: [ :create, :destroy, :index ]

        def create
          Like.find_or_create_by!(photo: photo, gallery_session: current_gallery_session)

          render_success(photo_state(photo))
        end

        def destroy
          Like.where(photo: photo, gallery_session: current_gallery_session).delete_all

          render_success(photo_state(photo))
        end

        def index
          likes = Like.includes(:photo).where(gallery_session: current_gallery_session)
          photos = likes.map(&:photo).sort_by { |item| [ item.sort_order, item.id ] }

          render_success(photos.map { |item| gallery_photo_payload(item) })
        end

        private

        def photo
          @photo ||= current_wedding.photos.ready.find(params[:photo_id])
        end

        def photo_state(record)
          {
            id: record.id,
            liked: liked_photo_ids.include?(record.id),
            shortlisted: shortlisted_photo_ids.include?(record.id)
          }
        end
      end
    end
  end
end
