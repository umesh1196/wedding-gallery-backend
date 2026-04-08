class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos, id: :uuid do |t|
      t.references :ceremony, type: :uuid, null: false, foreign_key: true
      t.references :wedding, type: :uuid, null: false, foreign_key: true
      t.references :studio_storage_connection, type: :uuid, foreign_key: true

      t.string :original_key, null: false
      t.string :thumbnail_key

      t.string :source_provider, null: false, default: "gallery_storage"
      t.string :source_bucket
      t.string :source_key
      t.string :source_etag

      t.text :blur_data_uri

      t.integer :width, null: false, default: 0
      t.integer :height, null: false, default: 0

      t.bigint :file_size_bytes, null: false, default: 0
      t.string :mime_type, null: false, default: "image/jpeg"
      t.string :original_filename
      t.string :file_extension, null: false, default: "jpg"

      t.jsonb :exif_data, default: {}

      t.integer :sort_order, null: false, default: 0
      t.boolean :is_cover, default: false

      t.string :ingestion_status, null: false, default: "pending_import"
      t.string :ingestion_error
      t.datetime :ingested_at

      t.string :processing_status, null: false, default: "pending"
      t.string :processing_error
      t.datetime :processed_at

      t.timestamps
    end

    execute <<~SQL
      ALTER TABLE photos ADD COLUMN aspect_ratio DECIMAL(5,3)
        GENERATED ALWAYS AS (
          CASE WHEN height > 0 THEN ROUND(width::decimal / height::decimal, 3) ELSE 0 END
        ) STORED;
    SQL

    add_index :photos, [ :ceremony_id, :sort_order ], where: "processing_status = 'ready'"
    add_index :photos, [ :wedding_id, :created_at ], where: "processing_status = 'ready'"
    add_index :photos, [ :ingestion_status, :created_at ], where: "ingestion_status IN ('pending_import', 'queued', 'uploading')"
    add_index :photos, [ :processing_status, :created_at ], where: "processing_status IN ('pending', 'processing')"
    add_index :photos, :ceremony_id, where: "is_cover = true", name: "idx_photos_cover_per_ceremony"
    add_index :photos,
              [ :ceremony_id, :source_provider, :source_bucket, :source_key, :source_etag ],
              unique: true,
              where: "source_key IS NOT NULL",
              name: "idx_photos_unique_import_source"
  end
end
