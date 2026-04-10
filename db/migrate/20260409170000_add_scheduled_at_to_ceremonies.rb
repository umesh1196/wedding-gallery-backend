class AddScheduledAtToCeremonies < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremonies, :scheduled_at, :datetime
    add_index :ceremonies, [ :wedding_id, :scheduled_at ]
  end
end
