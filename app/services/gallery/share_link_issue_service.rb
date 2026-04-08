module Gallery
  class ShareLinkIssueService
    def initialize(wedding:, gallery_session:, permissions:, label:)
      @wedding = wedding
      @gallery_session = gallery_session
      @permissions = permissions
      @label = label
    end

    def call
      ShareLink.issue!(
        wedding: @wedding,
        created_by: @gallery_session,
        permissions: @permissions,
        label: @label
      )
    end
  end
end
