module Api
  module V1
    module Gallery
      class SharedLinksController < ApplicationController
        def show
          share_link, _session, session_token = ::Gallery::ShareLinkRedeemService.new(
            token: params[:token],
            ip: request.remote_ip,
            user_agent: request.user_agent
          ).call

          render_success(
            {
              session_token: session_token,
              permissions: share_link.permissions,
              gallery: ::Gallery::PayloadBuilder.new(wedding: share_link.wedding).call
            }
          )
        rescue ::Gallery::ShareLinkRedeemService::InvalidShareLinkError => e
          render_error(e.message, status: :not_found, code: "not_found")
        end
      end
    end
  end
end
