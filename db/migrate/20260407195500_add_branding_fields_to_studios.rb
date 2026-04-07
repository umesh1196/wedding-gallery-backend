class AddBrandingFieldsToStudios < ActiveRecord::Migration[8.1]
  def change
    add_column :studios, :logo_url, :string
    add_column :studios, :color_primary, :string, default: "#1a1a1a", null: false
    add_column :studios, :color_accent, :string, default: "#c9a96e", null: false
    add_column :studios, :font_heading, :string, default: "Playfair Display", null: false
    add_column :studios, :font_body, :string, default: "Inter", null: false
    add_column :studios, :watermark_url, :string
    add_column :studios, :watermark_opacity, :decimal, precision: 3, scale: 2, default: 0.3, null: false
  end
end
