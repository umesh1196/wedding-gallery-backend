class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums, id: :uuid do |t|
      t.references :ceremony, null: false, foreign_key: true, type: :uuid
      t.references :created_by_studio, foreign_key: { to_table: :studios }, type: :uuid
      t.references :created_by_gallery_session, foreign_key: { to_table: :gallery_sessions }, type: :uuid
      t.string :album_type, null: false
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.references :cover_photo, foreign_key: { to_table: :photos }, type: :uuid
      t.string :visibility, default: "private", null: false
      t.integer :photos_count, default: 0, null: false

      t.timestamps
    end

    add_index :albums, [ :ceremony_id, :slug ], unique: true
    add_index :albums, [ :ceremony_id, :album_type, :created_at ]
  end
end
