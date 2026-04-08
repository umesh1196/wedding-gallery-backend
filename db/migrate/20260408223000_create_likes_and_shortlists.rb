class CreateLikesAndShortlists < ActiveRecord::Migration[8.1]
  def change
    create_table :likes, id: :uuid do |t|
      t.references :photo, type: :uuid, null: false, foreign_key: true
      t.references :gallery_session, type: :uuid, null: false, foreign_key: true
      t.timestamps
    end
    add_index :likes, [ :photo_id, :gallery_session_id ], unique: true

    create_table :shortlists, id: :uuid do |t|
      t.references :wedding, type: :uuid, null: false, foreign_key: true
      t.references :gallery_session, type: :uuid, null: false, foreign_key: true
      t.string :name, null: false, default: "My Shortlist"
      t.timestamps
    end
    add_index :shortlists, [ :wedding_id, :gallery_session_id ], unique: true

    create_table :shortlist_photos, id: :uuid do |t|
      t.references :shortlist, type: :uuid, null: false, foreign_key: true
      t.references :photo, type: :uuid, null: false, foreign_key: true
      t.integer :sort_order, null: false, default: 0
      t.string :note
      t.timestamps
    end
    add_index :shortlist_photos, [ :shortlist_id, :photo_id ], unique: true
    add_index :shortlist_photos, [ :shortlist_id, :sort_order ]
  end
end
