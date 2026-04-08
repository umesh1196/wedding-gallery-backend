module Api
  module V1
    module Gallery
      class CeremoniesController < BaseController
        def index
          ceremonies = current_wedding.ceremonies.order(:sort_order)

          render_success(
            ceremonies.map do |ceremony|
              {
                id: ceremony.id,
                name: ceremony.name,
                slug: ceremony.slug,
                sort_order: ceremony.sort_order,
                photo_count: ceremony.photo_count,
                cover_image_url: ceremony.cover_asset_url
              }
            end
          )
        end
      end
    end
  end
end
