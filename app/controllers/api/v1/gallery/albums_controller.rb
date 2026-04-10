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

        def photos
          records = album.album_photos.includes(:photo).order(:sort_order, :id).limit(limit + 1).to_a
          has_more = records.size > limit
          records = records.first(limit)

          render_success(
            records.map { |record| gallery_photo_payload(record.photo) },
            meta: { has_more: has_more }
          )
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
          ceremony.albums.where(album_type: "user_created", created_by_gallery_session_id: guest_session_ids_scope)
        end

        def album
          @album ||= albums_scope.find_by!(slug: params[:slug])
        rescue ActiveRecord::RecordNotFound
          @album = albums_scope.find(params[:slug])
        end

        def album_params
          params.require(:album).permit(:name, :slug, :description, :album_type, :visibility)
        end

        def limit
          requested = params[:limit].to_i
          return 60 if requested <= 0

          [ requested, 100 ].min
        end

        def guest_session_ids_scope
          if current_gallery_session.guest_identity_id.present?
            current_gallery_session.guest_identity.gallery_sessions.select(:id)
          else
            [ current_gallery_session.id ]
          end
        end
      end
    end
  end
end
