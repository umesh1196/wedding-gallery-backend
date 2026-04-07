module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_studio!

      private

      def authenticate_studio!
        token = extract_token
        payload = token && JwtService.decode(token)

        unless payload && (@current_studio = Studio.find_by(id: payload["studio_id"]))
          render_error("Unauthorized", status: :unauthorized, code: "unauthorized")
        end
      end

      def current_studio
        @current_studio
      end

      def extract_token
        auth_header = request.headers["Authorization"]
        auth_header&.start_with?("Bearer ") ? auth_header.split(" ").last : nil
      end
    end
  end
end
