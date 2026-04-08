class AddCoverImageKeyToCeremonies < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremonies, :cover_image_key, :string
  end
end
