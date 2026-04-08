class DownloadRequestBlueprint < Blueprinter::Base
  identifier :id

  fields :scope_type, :status, :filename, :completed_at, :expires_at, :error_message

  field :download_url do |request|
    next nil if request.archive_key.blank?
    next nil if request.expired?

    Storage::Service.new.presigned_download_url(key: request.archive_key, filename: request.filename)
  end
end
