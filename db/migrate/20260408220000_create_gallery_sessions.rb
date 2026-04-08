class CreateGallerySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :gallery_sessions, id: :uuid do |t|
      t.references :wedding, type: :uuid, foreign_key: true, null: false
      t.string :session_token_digest, null: false
      t.string :visitor_name
      t.string :role, null: false, default: "guest"
      t.string :last_ip
      t.string :last_user_agent
      t.datetime :last_active_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :gallery_sessions, :session_token_digest, unique: true
    add_index :gallery_sessions, :last_active_at
  end
end
