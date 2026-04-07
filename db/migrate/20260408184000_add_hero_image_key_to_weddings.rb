class AddHeroImageKeyToWeddings < ActiveRecord::Migration[8.1]
  def change
    add_column :weddings, :hero_image_key, :string
  end
end
