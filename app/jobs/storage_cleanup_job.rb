class StorageCleanupJob < ApplicationJob
  queue_as :default

  def perform(keys)
    Storage::Service.new.delete_batch(keys: Array(keys).compact_blank)
  end
end
