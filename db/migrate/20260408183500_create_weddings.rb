class CreateWeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :weddings, id: :uuid do |t|
      t.references :studio, type: :uuid, null: false, foreign_key: true
      t.string :couple_name, null: false
      t.date :wedding_date
      t.string :slug, null: false
      t.string :hero_image_url
      t.string :password_hash, null: false
      t.boolean :is_active, default: true, null: false
      t.datetime :expires_at, null: false
      t.string :allow_download, default: "shortlist", null: false
      t.boolean :allow_comments, default: true, null: false
      t.integer :total_photos, default: 0, null: false
      t.integer :total_videos, default: 0, null: false
      t.jsonb :metadata, default: {}, null: false
      t.timestamps
    end

    add_index :weddings, [ :studio_id, :slug ], unique: true
  end
end
