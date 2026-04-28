class CreatePersonPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :person_photos, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :person, type: :uuid, null: false, foreign_key: true, index: true
      t.references :photo, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
    end

    add_index :person_photos, [ :person_id, :photo_id ], unique: true, name: "index_person_photos_on_person_and_photo"
  end
end
