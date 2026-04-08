class PhotoUrlBuilder
  PRESETS = {
    preview: 1200,
    full: 2400
  }.freeze

  def initialize(photo, storage_service: Storage::Service.new)
    @photo = photo
    @storage_service = storage_service
  end

  def urls
    {
      blur: @photo.blur_data_uri,
      thumbnail: thumbnail_url,
      preview: transformed_url(:preview),
      full: transformed_url(:full),
      download: download_url
    }.compact
  end

  private

  def thumbnail_url
    return if @photo.thumbnail_key.blank?

    @storage_service.presigned_download_url(key: @photo.thumbnail_key)
  end

  def transformed_url(preset)
    if ENV["IMGPROXY_URL"].present?
      source = @storage_service.public_url(key: @photo.original_key)
      width = PRESETS.fetch(preset)
      "#{ENV['IMGPROXY_URL'].chomp('/')}/rs:fit:#{width}/plain/#{Base64.urlsafe_encode64(source)}"
    else
      @storage_service.presigned_download_url(key: @photo.original_key)
    end
  rescue StandardError
    @storage_service.presigned_download_url(key: @photo.original_key)
  end

  def download_url
    @storage_service.presigned_download_url(
      key: @photo.original_key,
      filename: @photo.original_filename
    )
  end
end
