class CreateStudios < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :studios, id: :uuid do |t|
      t.string :email,           null: false
      t.string :password_digest, null: false
      t.string :studio_name,     null: false
      t.string :slug,            null: false
      t.string :phone
      t.string :plan,            default: "free"
      t.datetime :plan_expires_at

      t.timestamps
    end

    add_index :studios, :email, unique: true
    add_index :studios, :slug,  unique: true
  end
end
