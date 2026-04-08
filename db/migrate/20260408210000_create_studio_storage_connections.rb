class CreateStudioStorageConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :studio_storage_connections, id: :uuid do |t|
      t.references :studio, type: :uuid, null: false, foreign_key: true
      t.string :label, null: false
      t.string :provider, null: false
      t.string :account_id
      t.string :bucket, null: false
      t.string :region
      t.string :endpoint
      t.string :access_key_ciphertext, null: false
      t.string :secret_key_ciphertext, null: false
      t.string :base_prefix
      t.boolean :is_default, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :studio_storage_connections,
              [ :studio_id, :is_default ],
              unique: true,
              where: "is_default = true",
              name: "idx_studio_storage_connections_one_default"
  end
end
