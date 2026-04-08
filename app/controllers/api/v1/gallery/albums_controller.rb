module Api
  module V1
    module Gallery
      class AlbumsController < BaseController
        def create
          album = ceremony.albums.new(album_params.merge(created_by_studio: nil, created_by_gallery_session: current_gallery_session))
          album.save!

          render_success(AlbumBlueprint.render_as_hash(album), status: :created)
        end

        def index
          render_success(AlbumBlueprint.render_as_hash(albums_scope.order(:name, :id)))
        end

        def show
          render_success(AlbumBlueprint.render_as_hash(album))
        end

        def update
          album.update!(album_params.except(:album_type))
          render_success(AlbumBlueprint.render_as_hash(album))
        end

        def destroy
          album.destroy!
          render_success({ id: album.id, deleted: true })
        end

        private

        def ceremony
          @ceremony ||= current_wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
        end

        def albums_scope
          ceremony.albums.where(album_type: "user_created", created_by_gallery_session: current_gallery_session)
        end

        def album
          @album ||= albums_scope.find_by!(slug: params[:slug])
        end

        def album_params
          params.require(:album).permit(:name, :slug, :description, :album_type, :visibility)
        end
      end
    end
  end
end
