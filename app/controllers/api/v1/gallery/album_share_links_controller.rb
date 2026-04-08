module Api
  module V1
    module Gallery
      class AlbumShareLinksController < BaseController
        def create
          share_link = AlbumShareLink.issue!(
            album: album,
            created_by_gallery_session: current_gallery_session,
            permissions: params.require(:permissions),
            label: params.require(:label)
          )

          render_success(AlbumShareLinkBlueprint.render_as_hash(share_link).merge(token: share_link.raw_token), status: :created)
        end

        private

        def ceremony
          @ceremony ||= current_wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
        end

        def album
          @album ||= ceremony.albums.where(album_type: "user_created", created_by_gallery_session: current_gallery_session).find_by!(slug: params[:album_slug])
        end
      end
    end
  end
end
