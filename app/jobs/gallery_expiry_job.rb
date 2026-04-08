class GalleryExpiryJob < ApplicationJob
  queue_as :default

  def perform
    weddings_to_expire.find_each do |wedding|
      wedding.transaction do
        wedding.update!(is_active: false)
        wedding.gallery_sessions.available.update_all(revoked_at: Time.current, updated_at: Time.current)
      end
    end
  end

  private

  def weddings_to_expire
    Wedding.where(is_active: true).where("expires_at < ?", Time.current)
  end
end
