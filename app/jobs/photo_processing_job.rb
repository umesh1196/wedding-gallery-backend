class PhotoProcessingJob < ApplicationJob
  queue_as :default

  def perform(photo_id)
    photo = Photo.find(photo_id)
    photo.update!(processing_status: "processing", processing_error: nil)

    tempfile = Storage::Service.new.download_to_tempfile(key: photo.original_key)
    image = Vips::Image.new_from_file(tempfile.path)
    thumbnail = image.thumbnail_image(300)
    thumbnail_buffer = thumbnail.webpsave_buffer(Q: 60)
    blur = image.thumbnail_image(20)
    blur_buffer = blur.webpsave_buffer(Q: 30)
    thumbnail_key = Storage::KeyBuilder.thumbnail(
      studio_id: photo.wedding.studio_id,
      wedding_id: photo.wedding_id,
      photo_id: photo.id
    )

    Storage::Service.new.upload(key: thumbnail_key, body: StringIO.new(thumbnail_buffer), content_type: "image/webp")

    photo.update!(
      thumbnail_key: thumbnail_key,
      blur_data_uri: "data:image/webp;base64,#{Base64.strict_encode64(blur_buffer)}",
      width: image.width,
      height: image.height,
      file_size_bytes: File.size(tempfile.path),
      exif_data: {},
      processing_status: "ready",
      processed_at: Time.current
    )
  rescue StandardError => e
    photo&.update!(processing_status: "failed", processing_error: e.message)
    raise
  ensure
    tempfile&.close
    tempfile&.unlink
  end
end
