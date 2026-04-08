class AddArchivedAtToWeddings < ActiveRecord::Migration[8.1]
  def change
    add_column :weddings, :archived_at, :datetime
    add_index :weddings, :archived_at
  end
end
