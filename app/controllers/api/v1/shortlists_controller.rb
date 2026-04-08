module Api
  module V1
    class ShortlistsController < BaseController
      def index
        render_success(
          wedding.shortlists.includes(:gallery_session, :shortlist_photos).order(created_at: :desc).map do |shortlist|
            {
              id: shortlist.id,
              visitor_name: shortlist.gallery_session.visitor_name,
              photo_count: shortlist.shortlist_photos.size,
              created_at: shortlist.created_at
            }
          end
        )
      end

      def show
        render_success(
          {
            id: shortlist.id,
            visitor_name: shortlist.gallery_session.visitor_name,
            photo_count: shortlist.shortlist_photos.size,
            created_at: shortlist.created_at,
            photos: shortlist.shortlist_photos.includes(:photo).order(:sort_order, :id).map do |item|
              {
                id: item.photo.id,
                note: item.note
              }
            end
          }
        )
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def shortlist
        @shortlist ||= wedding.shortlists.includes(:gallery_session, :shortlist_photos).find(params[:id])
      end
    end
  end
end
