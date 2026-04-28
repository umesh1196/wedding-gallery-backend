module Api
  module V1
    module Gallery
      class FaceSearchController < BaseController
        def create
          selfie = params.require(:selfie)

          result = FaceService::SearchService.new(
            wedding_id: current_wedding.id,
            selfie_file: selfie
          ).call

          render_success({
            photo_ids: result[:photo_ids],
            person: result[:person]
          })
        end
      end
    end
  end
end
