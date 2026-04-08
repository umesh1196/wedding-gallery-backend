class CreateDownloadRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :download_requests, id: :uuid do |t|
      t.references :wedding, null: false, type: :uuid, foreign_key: true
      t.references :gallery_session, null: false, type: :uuid, foreign_key: true
      t.references :ceremony, null: true, type: :uuid, foreign_key: true
      t.references :shortlist, null: true, type: :uuid, foreign_key: true
      t.string :scope_type, null: false
      t.string :status, null: false, default: "queued"
      t.string :filename, null: false
      t.string :archive_key
      t.string :error_message
      t.datetime :completed_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :download_requests, [ :gallery_session_id, :created_at ]
    add_index :download_requests, [ :wedding_id, :status ]
  end
end
