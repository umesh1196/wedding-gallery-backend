module GalleryDownloads
  class RequestCreateService
    def initialize(wedding:, gallery_session:, scope_type:, ceremony_slug: nil)
      @wedding = wedding
      @gallery_session = gallery_session
      @scope_type = scope_type.to_s
      @ceremony_slug = ceremony_slug
      @policy = Policy.new(wedding: wedding, gallery_session: gallery_session)
    end

    def call
      raise ForbiddenError, "Downloads are not allowed for this scope" unless @policy.allow_bulk_scope?(@scope_type)

      resolved = ScopeResolver.new(
        wedding: @wedding,
        gallery_session: @gallery_session,
        scope_type: @scope_type,
        ceremony_slug: @ceremony_slug
      ).call

      request = DownloadRequest.create!(
        wedding: @wedding,
        gallery_session: @gallery_session,
        ceremony: resolved[:ceremony],
        shortlist: resolved[:shortlist],
        scope_type: @scope_type,
        status: "queued",
        filename: resolved[:filename]
      )

      JobDispatch.enqueue(ZipGenerationJob, request.id)
      request
    end
  end
end
