class WeddingArchiveCleanupJob < ApplicationJob
  queue_as :default

  def perform
    storage_service = Storage::Service.new

    weddings_to_archive.find_each do |wedding|
      prefix = Storage::KeyBuilder.wedding_prefix(studio_id: wedding.studio_id, wedding_id: wedding.id)
      keys = storage_service.list(prefix: prefix)
      storage_service.delete_batch(keys: keys) if keys.any?
      wedding.update!(archived_at: Time.current)
    end
  end

  private

  def weddings_to_archive
    Wedding.where(is_active: false, archived_at: nil).where("expires_at < ?", 30.days.ago)
  end
end
