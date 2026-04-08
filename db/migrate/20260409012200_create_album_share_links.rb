class CreateAlbumShareLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :album_share_links, id: :uuid do |t|
      t.references :album, null: false, foreign_key: true, type: :uuid
      t.references :created_by_studio, foreign_key: { to_table: :studios }, type: :uuid
      t.references :created_by_gallery_session, foreign_key: { to_table: :gallery_sessions }, type: :uuid
      t.string :token_digest, null: false
      t.string :permissions, default: "view", null: false
      t.string :label
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :album_share_links, :token_digest, unique: true
    add_index :album_share_links, [ :album_id, :created_at ]
  end
end
