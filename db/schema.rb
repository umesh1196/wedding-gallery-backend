# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_08_223000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "ceremonies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cover_image_key"
    t.string "cover_image_url"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "photo_count", default: 0, null: false
    t.string "slug", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "video_count", default: 0, null: false
    t.uuid "wedding_id", null: false
    t.index ["wedding_id", "slug"], name: "index_ceremonies_on_wedding_id_and_slug", unique: true
    t.index ["wedding_id", "sort_order"], name: "index_ceremonies_on_wedding_id_and_sort_order"
    t.index ["wedding_id"], name: "index_ceremonies_on_wedding_id"
  end

  create_table "gallery_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_active_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "last_ip"
    t.string "last_user_agent"
    t.datetime "revoked_at"
    t.string "role", default: "guest", null: false
    t.string "session_token_digest", null: false
    t.datetime "updated_at", null: false
    t.string "visitor_name"
    t.uuid "wedding_id", null: false
    t.index ["last_active_at"], name: "index_gallery_sessions_on_last_active_at"
    t.index ["session_token_digest"], name: "index_gallery_sessions_on_session_token_digest", unique: true
    t.index ["wedding_id"], name: "index_gallery_sessions_on_wedding_id"
  end

  create_table "likes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "gallery_session_id", null: false
    t.uuid "photo_id", null: false
    t.datetime "updated_at", null: false
    t.index ["gallery_session_id"], name: "index_likes_on_gallery_session_id"
    t.index ["photo_id", "gallery_session_id"], name: "index_likes_on_photo_id_and_gallery_session_id", unique: true
    t.index ["photo_id"], name: "index_likes_on_photo_id"
  end

  create_table "photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.virtual "aspect_ratio", type: :decimal, precision: 5, scale: 3, as: "\nCASE\n    WHEN (height > 0) THEN round(((width)::numeric / (height)::numeric), 3)\n    ELSE (0)::numeric\nEND", stored: true
    t.text "blur_data_uri"
    t.uuid "ceremony_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "exif_data", default: {}
    t.string "file_extension", default: "jpg", null: false
    t.bigint "file_size_bytes", default: 0, null: false
    t.integer "height", default: 0, null: false
    t.datetime "ingested_at"
    t.string "ingestion_error"
    t.string "ingestion_status", default: "pending_import", null: false
    t.boolean "is_cover", default: false
    t.string "mime_type", default: "image/jpeg", null: false
    t.string "original_filename"
    t.string "original_key", null: false
    t.datetime "processed_at"
    t.string "processing_error"
    t.string "processing_status", default: "pending", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "source_bucket"
    t.string "source_etag"
    t.string "source_key"
    t.string "source_provider", default: "gallery_storage", null: false
    t.uuid "studio_storage_connection_id"
    t.string "thumbnail_key"
    t.datetime "updated_at", null: false
    t.uuid "upload_batch_id"
    t.uuid "wedding_id", null: false
    t.integer "width", default: 0, null: false
    t.index ["ceremony_id", "sort_order"], name: "index_photos_on_ceremony_id_and_sort_order", where: "((processing_status)::text = 'ready'::text)"
    t.index ["ceremony_id", "source_provider", "source_bucket", "source_key", "source_etag"], name: "idx_photos_unique_import_source", unique: true, where: "(source_key IS NOT NULL)"
    t.index ["ceremony_id"], name: "idx_photos_cover_per_ceremony", where: "(is_cover = true)"
    t.index ["ceremony_id"], name: "index_photos_on_ceremony_id"
    t.index ["ingestion_status", "created_at"], name: "index_photos_on_ingestion_status_and_created_at", where: "((ingestion_status)::text = ANY ((ARRAY['pending_import'::character varying, 'queued'::character varying, 'uploading'::character varying])::text[]))"
    t.index ["processing_status", "created_at"], name: "index_photos_on_processing_status_and_created_at", where: "((processing_status)::text = ANY ((ARRAY['pending'::character varying, 'processing'::character varying])::text[]))"
    t.index ["studio_storage_connection_id"], name: "index_photos_on_studio_storage_connection_id"
    t.index ["upload_batch_id"], name: "index_photos_on_upload_batch_id"
    t.index ["wedding_id", "created_at"], name: "index_photos_on_wedding_id_and_created_at", where: "((processing_status)::text = 'ready'::text)"
    t.index ["wedding_id"], name: "index_photos_on_wedding_id"
  end

  create_table "shortlist_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "note"
    t.uuid "photo_id", null: false
    t.uuid "shortlist_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_shortlist_photos_on_photo_id"
    t.index ["shortlist_id", "photo_id"], name: "index_shortlist_photos_on_shortlist_id_and_photo_id", unique: true
    t.index ["shortlist_id", "sort_order"], name: "index_shortlist_photos_on_shortlist_id_and_sort_order"
    t.index ["shortlist_id"], name: "index_shortlist_photos_on_shortlist_id"
  end

  create_table "shortlists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "gallery_session_id", null: false
    t.string "name", default: "My Shortlist", null: false
    t.datetime "updated_at", null: false
    t.uuid "wedding_id", null: false
    t.index ["gallery_session_id"], name: "index_shortlists_on_gallery_session_id"
    t.index ["wedding_id", "gallery_session_id"], name: "index_shortlists_on_wedding_id_and_gallery_session_id", unique: true
    t.index ["wedding_id"], name: "index_shortlists_on_wedding_id"
  end

  create_table "studio_storage_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "access_key_ciphertext", null: false
    t.string "account_id"
    t.boolean "active", default: true, null: false
    t.string "base_prefix"
    t.string "bucket", null: false
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.boolean "is_default", default: false, null: false
    t.string "label", null: false
    t.string "provider", null: false
    t.string "region"
    t.string "secret_key_ciphertext", null: false
    t.uuid "studio_id", null: false
    t.datetime "updated_at", null: false
    t.index ["studio_id", "is_default"], name: "idx_studio_storage_connections_one_default", unique: true, where: "(is_default = true)"
    t.index ["studio_id"], name: "index_studio_storage_connections_on_studio_id"
  end

  create_table "studios", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "color_accent", default: "#c9a96e", null: false
    t.string "color_primary", default: "#1a1a1a", null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "font_body", default: "Inter", null: false
    t.string "font_heading", default: "Playfair Display", null: false
    t.string "logo_key"
    t.string "logo_url"
    t.string "password_digest", null: false
    t.string "phone"
    t.string "plan", default: "free"
    t.datetime "plan_expires_at"
    t.string "slug", null: false
    t.string "studio_name", null: false
    t.datetime "updated_at", null: false
    t.string "watermark_key"
    t.decimal "watermark_opacity", precision: 3, scale: 2, default: "0.3", null: false
    t.string "watermark_url"
    t.index ["email"], name: "index_studios_on_email", unique: true
    t.index ["slug"], name: "index_studios_on_slug", unique: true
  end

  create_table "upload_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "ceremony_id", null: false
    t.integer "completed_files", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "failed_files", default: 0, null: false
    t.integer "skipped_files", default: 0, null: false
    t.string "source_type", default: "import", null: false
    t.string "status", default: "in_progress", null: false
    t.uuid "studio_id", null: false
    t.integer "total_files", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["ceremony_id"], name: "index_upload_batches_on_ceremony_id"
    t.index ["studio_id"], name: "index_upload_batches_on_studio_id"
  end

  create_table "weddings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "allow_comments", default: true, null: false
    t.string "allow_download", default: "shortlist", null: false
    t.string "couple_name", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "hero_image_key"
    t.string "hero_image_url"
    t.boolean "is_active", default: true, null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "password_hash", null: false
    t.string "slug", null: false
    t.uuid "studio_id", null: false
    t.integer "total_photos", default: 0, null: false
    t.integer "total_videos", default: 0, null: false
    t.datetime "updated_at", null: false
    t.date "wedding_date"
    t.index ["studio_id", "slug"], name: "index_weddings_on_studio_id_and_slug", unique: true
    t.index ["studio_id"], name: "index_weddings_on_studio_id"
  end

  add_foreign_key "ceremonies", "weddings"
  add_foreign_key "gallery_sessions", "weddings"
  add_foreign_key "likes", "gallery_sessions"
  add_foreign_key "likes", "photos"
  add_foreign_key "photos", "ceremonies"
  add_foreign_key "photos", "studio_storage_connections"
  add_foreign_key "photos", "upload_batches"
  add_foreign_key "photos", "weddings"
  add_foreign_key "shortlist_photos", "photos"
  add_foreign_key "shortlist_photos", "shortlists"
  add_foreign_key "shortlists", "gallery_sessions"
  add_foreign_key "shortlists", "weddings"
  add_foreign_key "studio_storage_connections", "studios"
  add_foreign_key "upload_batches", "ceremonies"
  add_foreign_key "upload_batches", "studios"
  add_foreign_key "weddings", "studios"
end
