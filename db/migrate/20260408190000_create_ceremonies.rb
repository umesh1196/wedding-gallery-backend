class CreateCeremonies < ActiveRecord::Migration[8.1]
  def change
    create_table :ceremonies, id: :uuid do |t|
      t.references :wedding, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :cover_image_url
      t.text :description
      t.integer :sort_order, null: false, default: 0
      t.integer :photo_count, null: false, default: 0
      t.integer :video_count, null: false, default: 0
      t.timestamps
    end

    add_index :ceremonies, [ :wedding_id, :slug ], unique: true
    add_index :ceremonies, [ :wedding_id, :sort_order ]
  end
end
