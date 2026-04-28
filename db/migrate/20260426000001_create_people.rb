class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :wedding, type: :uuid, null: false, foreign_key: true, index: true
      t.string :label, null: false
      t.string :avatar_url
      t.boolean :is_known, null: false, default: false
      t.timestamps
    end

    add_index :people, [ :wedding_id, :label ], unique: true, name: "index_people_on_wedding_id_and_label"
  end
end
