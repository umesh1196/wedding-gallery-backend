module Api
  module V1
    module Gallery
      class DownloadsController < BaseController
        def download_photo
          payload = GalleryDownloads::SinglePhotoDownloadService.new(
            photo: photo,
            wedding: current_wedding,
            gallery_session: current_gallery_session
          ).call

          render_success(payload)
        rescue GalleryDownloads::ForbiddenError => e
          render_error(e.message, status: :forbidden, code: "forbidden")
        end

        def create
          request_record = GalleryDownloads::RequestCreateService.new(
            wedding: current_wedding,
            gallery_session: current_gallery_session,
            scope_type: params.require(:type),
            ceremony_slug: params[:ceremony_slug]
          ).call

          render_success(DownloadRequestBlueprint.render_as_hash(request_record), status: :accepted)
        rescue GalleryDownloads::ForbiddenError => e
          render_error(e.message, status: :forbidden, code: "forbidden")
        end

        def show
          request_record = current_wedding.download_requests.find_by!(id: params[:id], gallery_session_id: current_gallery_session.id)
          request_record.mark_expired! if request_record.expired? && request_record.status == "ready"

          render_success(DownloadRequestBlueprint.render_as_hash(request_record.reload))
        end

        private

        def photo
          @photo ||= current_wedding.photos.ready.find(params[:photo_id])
        end
      end
    end
  end
end
