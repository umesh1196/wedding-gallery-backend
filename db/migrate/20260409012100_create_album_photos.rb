class CreateAlbumPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :album_photos, id: :uuid do |t|
      t.references :album, null: false, foreign_key: true, type: :uuid
      t.references :photo, null: false, foreign_key: true, type: :uuid
      t.integer :sort_order, default: 0, null: false

      t.timestamps
    end

    add_index :album_photos, [ :album_id, :photo_id ], unique: true
    add_index :album_photos, [ :album_id, :sort_order ]
  end
end
