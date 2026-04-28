module Api
  module V1
    module Gallery
      class PeopleController < BaseController
        def index
          people = current_wedding.people
                     .joins(:person_photos)
                     .select("people.*, COUNT(person_photos.id) AS photo_count")
                     .group("people.id")
                     .order("photo_count DESC")

          render_success(people.map { |p|
            {
              id: p.id,
              label: p.label,
              avatar_url: p.avatar_url,
              photo_count: p.photo_count.to_i,
              is_known: p.is_known
            }
          })
        end

        def photos
          person = current_wedding.people.find(params[:person_id])
          photo_ids = person.person_photos.pluck(:photo_id)
          photos = current_wedding.photos.ready
                     .where(id: photo_ids)
                     .includes(:people)
                     .order(:sort_order, :id)

          render_success(photos.map { |photo| gallery_photo_payload(photo) })
        end
      end
    end
  end
end
