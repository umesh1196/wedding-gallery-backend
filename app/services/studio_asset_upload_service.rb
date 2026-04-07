class StudioAssetUploadService
  class UploadError < StandardError; end

  MAX_FILE_SIZE = 2.megabytes
  ALLOWED_CONTENT_TYPES = {
    "image/png" => "png",
    "image/jpeg" => "jpg",
    "image/svg+xml" => "svg"
  }.freeze

  def initialize(studio:, upload:, asset_type:, storage_service: Storage::Service.new)
    @studio = studio
    @upload = upload
    @asset_type = asset_type.to_sym
    @storage_service = storage_service
  end

  def call
    validate_upload!

    content_type = detected_content_type
    ext = extension_for(content_type)
    payload = svg?(content_type) ? svg_payload : processed_raster_payload
    key = storage_key(ext: ext)

    @storage_service.upload(key: key, body: payload[:body], content_type: payload[:content_type])
    @studio.update!(asset_key_attribute => key)

    { key: key, url: @storage_service.presigned_download_url(key: key) }
  ensure
    payload[:body]&.close! if payload && payload[:body].is_a?(Tempfile)
  end

  private

  def validate_upload!
    raise UploadError, "File is required" if @upload.blank?
    raise UploadError, "Unsupported file type" unless ALLOWED_CONTENT_TYPES.key?(detected_content_type)
    raise UploadError, "File size must be less than 2MB" if @upload.size > MAX_FILE_SIZE
  end

  def detected_content_type
    @detected_content_type ||= Marcel::MimeType.for(@upload.tempfile, name: @upload.original_filename, declared_type: @upload.content_type)
  end

  def extension_for(content_type)
    ALLOWED_CONTENT_TYPES.fetch(content_type)
  end

  def svg?(content_type)
    content_type == "image/svg+xml"
  end

  def svg_payload
    tempfile = Tempfile.new([ asset_type_name, ".svg" ])
    tempfile.binmode
    @upload.tempfile.rewind
    IO.copy_stream(@upload.tempfile, tempfile)
    tempfile.rewind

    { body: tempfile, content_type: "image/svg+xml" }
  end

  def processed_raster_payload
    tempfile = Tempfile.new([ asset_type_name, ".jpg" ])
    tempfile.binmode

    ImageProcessing::Vips
      .source(@upload.tempfile.path)
      .resize_to_limit(400, 400)
      .convert("jpg")
      .saver(strip: true, Q: 85)
      .call(destination: tempfile.path)

    tempfile.rewind
    { body: tempfile, content_type: "image/jpeg" }
  end

  def storage_key(ext:)
    case @asset_type
    when :logo
      Storage::KeyBuilder.studio_logo(studio_id: @studio.id, ext: ext)
    when :watermark
      Storage::KeyBuilder.studio_watermark(studio_id: @studio.id, ext: ext)
    else
      raise UploadError, "Unsupported asset type"
    end
  end

  def asset_key_attribute
    "#{@asset_type}_key"
  end

  def asset_type_name
    @asset_type.to_s
  end
end
