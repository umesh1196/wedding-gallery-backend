module Api
  module V1
    module Gallery
      class BootstrapsController < BaseController
        def show
          render_success(::Gallery::PayloadBuilder.new(wedding: current_wedding).call)
        end
      end
    end
  end
end
