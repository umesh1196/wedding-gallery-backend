module GalleryDownloads
  class RequestCreateService
    def initialize(wedding:, gallery_session:, scope_type:, ceremony_slug: nil, photo_ids: [])
      @wedding = wedding
      @gallery_session = gallery_session
      @scope_type = scope_type.to_s
      @ceremony_slug = ceremony_slug
      @photo_ids = Array(photo_ids).map(&:to_s)
      @policy = Policy.new(wedding: wedding, gallery_session: gallery_session)
    end

    def call
      raise ForbiddenError, "Downloads are not allowed for this scope" unless @policy.allow_bulk_scope?(@scope_type, photo_ids: @photo_ids)

      resolved = ScopeResolver.new(
        wedding: @wedding,
        gallery_session: @gallery_session,
        scope_type: @scope_type,
        ceremony_slug: @ceremony_slug,
        photo_ids: @photo_ids
      ).call

      request = DownloadRequest.create!(
        wedding: @wedding,
        gallery_session: @gallery_session,
        ceremony: resolved[:ceremony],
        shortlist: resolved[:shortlist],
        scope_type: @scope_type,
        selected_photo_ids: @scope_type == "selected_photos" ? @photo_ids : [],
        status: "queued",
        filename: resolved[:filename]
      )

      JobDispatch.enqueue(ZipGenerationJob, request.id)
      request
    end
  end
end
