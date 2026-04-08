module Api
  module V1
    module Gallery
      class BaseController < ApplicationController
        before_action :authenticate_gallery_session!

        private

        def authenticate_gallery_session!
          token = request.headers["X-Gallery-Token"].to_s
          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized") if token.blank?

          digest = GallerySession.digest_token(token)
          @current_gallery_session = GallerySession.includes(wedding: :studio).find_by(session_token_digest: digest)

          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized") if @current_gallery_session.blank?
          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized") unless @current_gallery_session.active?

          @current_wedding = @current_gallery_session.wedding
          return render_error("Gallery expired", status: :gone, code: "gallery_expired") if @current_wedding.expired?
          return render_error("Unauthorized", status: :unauthorized, code: "unauthorized") unless route_matches_session_wedding?

          @current_gallery_session.touch_activity!(ip: request.remote_ip, user_agent: request.user_agent)
        end

        def current_gallery_session
          @current_gallery_session
        end

        def current_wedding
          @current_wedding
        end

        def current_studio
          current_wedding.studio
        end

        def route_matches_session_wedding?
          current_wedding.slug == params[:wedding_slug] && current_studio.slug == params[:studio_slug]
        end
      end
    end
  end
end
