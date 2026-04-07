class WeddingHeroUploadService
  class UploadError < StandardError; end

  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_CONTENT_TYPES = %w[image/png image/jpeg image/svg+xml].freeze

  def initialize(wedding:, upload:, storage_service: Storage::Service.new)
    @wedding = wedding
    @upload = upload
    @storage_service = storage_service
  end

  def call
    validate_upload!

    hero_tempfile = Tempfile.new([ "hero", ".jpg" ])
    blur_tempfile = Tempfile.new([ "hero-blur", ".jpg" ])
    hero_tempfile.binmode
    blur_tempfile.binmode

    ImageProcessing::Vips
      .source(@upload.tempfile.path)
      .resize_to_limit(2400, 2400)
      .convert("jpg")
      .saver(strip: true, Q: 85)
      .call(destination: hero_tempfile.path)

    ImageProcessing::Vips
      .source(@upload.tempfile.path)
      .resize_to_limit(32, 32)
      .convert("jpg")
      .saver(strip: true, Q: 50)
      .call(destination: blur_tempfile.path)

    key = Storage::KeyBuilder.hero(studio_id: @wedding.studio_id, wedding_id: @wedding.id)
    hero_tempfile.rewind
    @storage_service.upload(key: key, body: hero_tempfile, content_type: "image/jpeg")
    @wedding.update!(hero_image_key: key)

    {
      key: key,
      url: @storage_service.presigned_download_url(key: key),
      blur_data_url: blur_data_url(blur_tempfile)
    }
  ensure
    hero_tempfile&.close!
    blur_tempfile&.close!
  end

  private

  def validate_upload!
    raise UploadError, "File is required" if @upload.blank?
    raise UploadError, "Unsupported file type" unless ALLOWED_CONTENT_TYPES.include?(detected_content_type)
    raise UploadError, "File size must be less than 10MB" if @upload.size > MAX_FILE_SIZE
  end

  def detected_content_type
    @detected_content_type ||= Marcel::MimeType.for(@upload.tempfile, name: @upload.original_filename, declared_type: @upload.content_type)
  end

  def blur_data_url(tempfile)
    tempfile.rewind
    encoded = Base64.strict_encode64(tempfile.read)
    "data:image/jpeg;base64,#{encoded}"
  end
end
