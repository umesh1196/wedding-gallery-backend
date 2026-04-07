class AddAssetKeysToStudios < ActiveRecord::Migration[8.1]
  def change
    add_column :studios, :logo_key, :string
    add_column :studios, :watermark_key, :string
  end
end
