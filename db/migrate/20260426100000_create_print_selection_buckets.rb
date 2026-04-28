class CreatePrintSelectionBuckets < ActiveRecord::Migration[8.1]
  def change
    create_table :print_selection_buckets, id: :uuid do |t|
      t.references :wedding, null: false, foreign_key: true, type: :uuid
      t.references :created_by_studio, null: false, foreign_key: { to_table: :studios }, type: :uuid
      t.string :name, null: false
      t.string :slug, null: false
      t.integer :selection_limit, null: false, default: 0
      t.integer :selected_count, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.datetime :locked_at
      t.timestamps
    end

    add_index :print_selection_buckets, [ :wedding_id, :slug ], unique: true
    add_index :print_selection_buckets, [ :wedding_id, :sort_order ]

    create_table :print_selection_photos, id: :uuid do |t|
      t.references :print_selection_bucket, null: false, foreign_key: true, type: :uuid
      t.references :photo, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end

    add_index :print_selection_photos, [ :print_selection_bucket_id, :photo_id ], unique: true, name: "idx_print_selection_bucket_photo"
    add_index :print_selection_photos, [ :print_selection_bucket_id, :created_at ], name: "idx_print_selection_bucket_created_at"
  end
end
