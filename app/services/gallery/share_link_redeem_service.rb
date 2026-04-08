module Gallery
  class ShareLinkRedeemService
    class InvalidShareLinkError < StandardError; end

    def initialize(token:, ip:, user_agent:)
      @token = token.to_s
      @ip = ip
      @user_agent = user_agent
    end

    def call
      share_link = ShareLink.find_by(token_digest: ShareLink.digest_token(@token))
      raise InvalidShareLinkError, "Share link not found" if share_link.blank?
      raise InvalidShareLinkError, "Share link is no longer active" unless share_link.active?

      session, raw_token = GallerySession.issue_for!(
        wedding: share_link.wedding,
        visitor_name: share_link.created_by.visitor_name,
        ip: @ip,
        user_agent: @user_agent,
        share_link: share_link,
        permissions: share_link.permissions
      )

      [ share_link, session, raw_token ]
    end
  end
end
