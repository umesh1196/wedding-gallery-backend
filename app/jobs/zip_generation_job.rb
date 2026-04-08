require "zip"

class ZipGenerationJob < ApplicationJob
  queue_as :downloads

  def perform(download_request_id)
    request = DownloadRequest.find(download_request_id)
    request.update!(status: "processing", error_message: nil)

    resolved = GalleryDownloads::ScopeResolver.new(
      wedding: request.wedding,
      gallery_session: request.gallery_session,
      scope_type: request.scope_type,
      ceremony_slug: request.ceremony&.slug
    ).call

    raise "No photos available for download" if resolved[:photos].empty?

    storage_service = Storage::Service.new
    archive = Tempfile.new([ "download-archive", ".zip" ])
    archive.binmode

    begin
      build_archive(archive.path, resolved[:photos], storage_service)
      archive.rewind

      archive_key = Storage::KeyBuilder.download_archive(
        studio_id: request.wedding.studio_id,
        wedding_id: request.wedding_id,
        download_request_id: request.id
      )

      storage_service.upload_file(key: archive_key, file_path: archive.path, content_type: "application/zip")

      request.update!(
        status: "ready",
        archive_key: archive_key,
        completed_at: Time.current,
        expires_at: DownloadRequest::EXPIRY_WINDOW.from_now,
        error_message: nil
      )
    ensure
      archive.close
      archive.unlink
    end
  rescue StandardError => e
    request&.update!(status: "failed", error_message: e.message)
    raise
  end

  private

  def build_archive(path, photos, storage_service)
    Zip::File.open(path, create: true) do |zip|
      photos.each_with_index do |photo, index|
        # Archive the gallery-managed original file so bulk downloads match single-photo downloads.
        source = storage_service.download_to_tempfile(key: photo.original_key)
        entry_name = format("%03d-%s", index + 1, photo.original_filename.presence || "photo-#{photo.id}.#{photo.file_extension}")
        zip.get_output_stream(entry_name) do |stream|
          source.rewind
          IO.copy_stream(source, stream)
        end
      ensure
        source&.close
        source&.unlink
      end
    end
  end
end
