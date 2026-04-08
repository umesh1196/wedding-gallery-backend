class AddShareLinkFieldsToGallerySessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :gallery_sessions, :share_link, foreign_key: true, type: :uuid
    add_column :gallery_sessions, :permissions, :string
    add_index :gallery_sessions, [ :share_link_id, :created_at ]
  end
end
