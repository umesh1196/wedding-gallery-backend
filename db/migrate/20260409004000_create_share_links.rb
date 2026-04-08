class CreateShareLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :share_links, id: :uuid do |t|
      t.references :wedding, null: false, foreign_key: true, type: :uuid
      t.references :created_by, null: false, foreign_key: { to_table: :gallery_sessions }, type: :uuid
      t.string :token_digest, null: false
      t.string :permissions, null: false
      t.string :label, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :share_links, :token_digest, unique: true
    add_index :share_links, [ :wedding_id, :created_at ]
  end
end
