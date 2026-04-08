module Api
  module V1
    module Gallery
      class PhotosController < BaseController
        DEFAULT_LIMIT = 60
        MAX_LIMIT = 100

        def index
          photos = ceremony.photos.ready.order(:sort_order, :id)
          photos = apply_cursor(photos)
          photos = photos.limit(limit + 1)
          records = photos.to_a
          has_more = records.size > limit
          records = records.first(limit)

          render_success(
            records.map { |photo| photo_payload(photo) },
            meta: {
              next_cursor: has_more ? encode_cursor(records.last) : nil,
              has_more: has_more
            }
          )
        end

        private

        def ceremony
          @ceremony ||= current_wedding.ceremonies.find_by!(slug: params[:ceremony_slug])
        end

        def limit
          requested = params[:limit].to_i
          return DEFAULT_LIMIT if requested <= 0

          [ requested, MAX_LIMIT ].min
        end

        def apply_cursor(scope)
          return scope if params[:cursor].blank?

          sort_order, id = decode_cursor(params[:cursor])
          scope.where("sort_order > :sort_order OR (sort_order = :sort_order AND id > :id)", sort_order: sort_order, id: id)
        rescue ArgumentError
          scope
        end

        def encode_cursor(photo)
          Base64.urlsafe_encode64("#{photo.sort_order}:#{photo.id}", padding: false)
        end

        def decode_cursor(cursor)
          decoded = Base64.urlsafe_decode64(cursor.to_s)
          sort_order, id = decoded.split(":", 2)
          raise ArgumentError if sort_order.blank? || id.blank?

          [ Integer(sort_order, 10), id ]
        end

        def photo_payload(photo)
          urls = PhotoUrlBuilder.new(photo).urls

          {
            id: photo.id,
            thumbnail_url: urls[:thumbnail],
            preview_url: urls[:preview],
            blur_hash: urls[:blur],
            width: photo.width,
            height: photo.height
          }
        end
      end
    end
  end
end
