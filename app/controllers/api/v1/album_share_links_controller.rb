module Api
  module V1
    class AlbumShareLinksController < BaseController
      def create
        share_link = AlbumShareLink.issue!(
          album: album,
          created_by_studio: current_studio,
          permissions: params.require(:permissions),
          label: params.require(:label)
        )

        render_success(AlbumShareLinkBlueprint.render_as_hash(share_link).merge(token: share_link.raw_token), status: :created)
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def ceremony
        @ceremony ||= wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
      end

      def album
        @album ||= ceremony.albums.where(album_type: "studio_curated").find_by!(slug: params[:album_slug])
      end
    end
  end
end
