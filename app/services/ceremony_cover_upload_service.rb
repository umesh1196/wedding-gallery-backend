class CeremonyCoverUploadService
  class UploadError < StandardError; end

  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml].freeze

  def initialize(ceremony:, upload:, storage_service: Storage::Service.new)
    @ceremony = ceremony
    @upload = upload
    @storage_service = storage_service
  end

  def call
    validate_upload!

    cover_tempfile = Tempfile.new([ "ceremony-cover", ".jpg" ])
    cover_tempfile.binmode

    ImageProcessing::Vips
      .source(@upload.tempfile.path)
      .resize_to_limit(1800, 1800)
      .convert("jpg")
      .saver(strip: true, Q: 85)
      .call(destination: cover_tempfile.path)

    key = Storage::KeyBuilder.ceremony_cover(
      studio_id: @ceremony.wedding.studio_id,
      wedding_id: @ceremony.wedding_id,
      ceremony_id: @ceremony.id
    )

    cover_tempfile.rewind
    @storage_service.upload(key: key, body: cover_tempfile, content_type: "image/jpeg")
    @ceremony.update!(cover_image_key: key)

    {
      key: key,
      url: @storage_service.presigned_download_url(key: key)
    }
  ensure
    cover_tempfile&.close!
  end

  private

  def validate_upload!
    raise UploadError, "File is required" if @upload.blank?
    raise UploadError, "Unsupported file type" unless ALLOWED_CONTENT_TYPES.include?(detected_content_type)
    raise UploadError, "File size must be less than 10MB" if @upload.size > MAX_FILE_SIZE
  end

  def detected_content_type
    @detected_content_type ||= Marcel::MimeType.for(
      @upload.tempfile,
      name: @upload.original_filename,
      declared_type: @upload.content_type
    )
  end
end
