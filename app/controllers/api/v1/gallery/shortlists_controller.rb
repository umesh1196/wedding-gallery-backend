module Api
  module V1
    module Gallery
      class ShortlistsController < BaseController
        def show
          render_success(shortlist_payload(shortlist))
        end

        def add_photos
          items = photo_ids.map.with_index do |photo_id, index|
            shortlist.shortlist_photos.find_or_initialize_by(photo_id: photo_id).tap do |item|
              item.sort_order = next_sort_order + index if item.new_record?
              item.save!
            end
          end

          render_success(shortlist_payload(shortlist.reload))
        end

        def remove_photo
          shortlist.shortlist_photos.where(photo_id: photo.id).delete_all
          normalize_sort_order!

          render_success(shortlist_payload(shortlist.reload))
        end

        def reorder
          items_by_photo_id = shortlist.shortlist_photos.where(photo_id: order_photo_ids).index_by(&:photo_id)
          missing_ids = order_photo_ids - items_by_photo_id.keys
          raise ActiveRecord::RecordNotFound, "Couldn't find ShortlistPhoto with provided photo ids" if missing_ids.any?

          ShortlistPhoto.transaction do
            order_photo_ids.each_with_index do |photo_id, index|
              items_by_photo_id.fetch(photo_id).update_columns(sort_order: index, updated_at: Time.current)
            end
          end

          render_success(shortlist_payload(shortlist.reload))
        end

        private

        def shortlist
          @shortlist ||= Shortlist.find_or_create_by!(wedding: current_wedding, gallery_session: current_gallery_session) do |record|
            record.name = "My Shortlist"
          end
        end

        def photo
          @photo ||= current_wedding.photos.ready.find(params[:photo_id])
        end

        def photo_ids
          Array(params.require(:photo_ids)).map(&:to_s).uniq.tap do |ids|
            requested = current_wedding.photos.ready.where(id: ids).pluck(:id)
            missing = ids - requested
            raise ActiveRecord::RecordNotFound, "Couldn't find Photo with provided ids" if missing.any?
          end
        end

        def order_photo_ids
          Array(params.require(:order)).map(&:to_s)
        end

        def next_sort_order
          shortlist.shortlist_photos.maximum(:sort_order).to_i + 1
        end

        def normalize_sort_order!
          shortlist.shortlist_photos.order(:sort_order, :id).each_with_index do |item, index|
            item.update_columns(sort_order: index, updated_at: Time.current)
          end
        end

        def shortlist_payload(record)
          {
            id: record.id,
            name: record.name,
            photo_count: record.shortlist_photos.size,
            photos: record.shortlist_photos.includes(:photo).map do |item|
              gallery_photo_payload(item.photo).merge(note: item.note)
            end
          }
        end
      end
    end
  end
end
