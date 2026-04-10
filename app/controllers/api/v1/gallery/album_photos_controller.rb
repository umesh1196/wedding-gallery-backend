module Api
  module V1
    module Gallery
      class AlbumPhotosController < BaseController
        def create
          AlbumPhoto.transaction do
            photo_ids.each_with_index do |photo_id, index|
              album.album_photos.find_or_create_by!(photo: ceremony.photos.ready.find(photo_id)) do |record|
                record.sort_order = album.album_photos.count + index
              end
            end
          end

          render_success(AlbumBlueprint.render_as_hash(album.reload))
        end

        def destroy
          album.album_photos.find_by!(photo: ceremony.photos.ready.find(params[:photo_id])).destroy!
          render_success(AlbumBlueprint.render_as_hash(album.reload))
        end

        def reorder
          ordered = album.album_photos.where(photo_id: photo_ids).index_by { |record| record.photo_id }
          missing_ids = photo_ids - ordered.keys
          raise ActiveRecord::RecordNotFound, "Couldn't find AlbumPhoto with provided ids" if missing_ids.any?

          AlbumPhoto.transaction do
            photo_ids.each_with_index do |photo_id, index|
              ordered.fetch(photo_id).update_columns(sort_order: index, updated_at: Time.current)
            end
          end

          render_success(AlbumBlueprint.render_as_hash(album.reload))
        end

        def cover
          photo = ceremony.photos.ready.find(params.require(:photo_id))
          raise ActiveRecord::RecordNotFound, "Couldn't find Photo in album" unless album.photos.exists?(photo.id)

          album.update!(cover_photo: photo)
          render_success(AlbumBlueprint.render_as_hash(album))
        end

        private

        def ceremony
          @ceremony ||= current_wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
        end

        def album
          @album ||= ceremony.albums.where(album_type: "user_created", created_by_gallery_session_id: guest_session_ids_scope).find_by!(slug: params[:album_slug])
        end

        def guest_session_ids_scope
          if current_gallery_session.guest_identity_id.present?
            current_gallery_session.guest_identity.gallery_sessions.select(:id)
          else
            [ current_gallery_session.id ]
          end
        end

        def photo_ids
          Array(params[:photo_ids] || params[:order]).map(&:to_s)
        end
      end
    end
  end
end
