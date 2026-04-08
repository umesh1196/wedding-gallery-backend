class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments, id: :uuid do |t|
      t.references :photo, type: :uuid, null: false, foreign_key: true
      t.references :gallery_session, type: :uuid, null: false, foreign_key: true
      t.string :visitor_name_snapshot
      t.text :body, null: false

      t.timestamps
    end

    add_column :photos, :comments_count, :integer, default: 0, null: false
  end
end
