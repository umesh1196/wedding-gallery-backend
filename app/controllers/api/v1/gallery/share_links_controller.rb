module Api
  module V1
    module Gallery
      class ShareLinksController < BaseController
        def create
          share_link = ::Gallery::ShareLinkIssueService.new(
            wedding: current_wedding,
            gallery_session: current_gallery_session,
            permissions: params.require(:permissions),
            label: params.require(:label)
          ).call

          render_success(
            {
              id: share_link.id,
              token: share_link.raw_token,
              permissions: share_link.permissions,
              label: share_link.label,
              expires_at: share_link.expires_at
            },
            status: :created
          )
        end
      end
    end
  end
end
