module GalleryDownloads
  class SinglePhotoDownloadService
    def initialize(photo:, wedding:, gallery_session:, storage_service: Storage::Service.new)
      @photo = photo
      @wedding = wedding
      @gallery_session = gallery_session
      @storage_service = storage_service
      @policy = Policy.new(wedding: wedding, gallery_session: gallery_session)
    end

    def call
      raise GalleryDownloads::ForbiddenError, "Downloads are not allowed for this photo" unless @policy.allow_single_photo?(@photo)

      {
        # Downloads should always use the gallery-managed original asset, never a preview derivative.
        download_url: @storage_service.presigned_download_url(
          key: @photo.original_key,
          filename: @photo.original_filename
        ),
        filename: @photo.original_filename,
        expires_at: 1.hour.from_now.iso8601
      }
    end
  end
end
