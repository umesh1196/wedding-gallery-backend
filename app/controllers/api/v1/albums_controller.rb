module Api
  module V1
    class AlbumsController < BaseController
      def create
        album = ceremony.albums.new(album_params.merge(created_by_studio: current_studio, created_by_gallery_session: nil))
        album.save!

        render_success(AlbumBlueprint.render_as_hash(album), status: :created)
      end

      def index
        render_success(AlbumBlueprint.render_as_hash(ceremony.albums.where(album_type: "studio_curated").order(:name, :id)))
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

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def ceremony
        @ceremony ||= wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
      end

      def album
        @album ||= ceremony.albums.where(album_type: "studio_curated").find_by!(slug: params[:slug])
      end

      def album_params
        params.require(:album).permit(:name, :slug, :description, :album_type, :visibility)
      end
    end
  end
end
