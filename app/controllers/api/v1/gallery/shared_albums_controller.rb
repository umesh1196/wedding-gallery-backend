module Api
  module V1
    module Gallery
      class SharedAlbumsController < ApplicationController
        DEFAULT_LIMIT = 60
        MAX_LIMIT = 100

        def show
          render_success(
            {
              album: AlbumBlueprint.render_as_hash(album),
              permissions: share_link.permissions,
              ceremony: {
                slug: album.ceremony.slug,
                name: album.ceremony.name
              },
              wedding: {
                slug: album.wedding.slug,
                couple_name: album.wedding.couple_name
              }
            }
          )
        end

        def photos
          records = album.album_photos.includes(:photo).order(:sort_order, :id).limit(limit + 1).to_a
          has_more = records.size > limit
          records = records.first(limit)

          render_success(
            records.map { |record| photo_payload(record.photo) },
            meta: {
              has_more: has_more,
              permissions: share_link.permissions
            }
          )
        end

        private

        def share_link
          @share_link ||= begin
            link = AlbumShareLink.find_by!(token_digest: AlbumShareLink.digest_token(params[:token]))
            raise ActiveRecord::RecordNotFound, "Couldn't find AlbumShareLink" unless link.active?

            link
          end
        end

        def album
          @album ||= share_link.album
        end

        def limit
          requested = params[:limit].to_i
          return DEFAULT_LIMIT if requested <= 0

          [ requested, MAX_LIMIT ].min
        end

        def photo_payload(photo)
          ::Gallery::PhotoPayloadBuilder.new(photo: photo).call
        end
      end
    end
  end
end
