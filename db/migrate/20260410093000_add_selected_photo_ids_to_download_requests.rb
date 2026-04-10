class AddSelectedPhotoIdsToDownloadRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :download_requests, :selected_photo_ids, :jsonb, null: false, default: []
  end
end
