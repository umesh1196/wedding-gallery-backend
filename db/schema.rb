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

ActiveRecord::Schema[8.1].define(version: 2026_04_07_201500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

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
end
