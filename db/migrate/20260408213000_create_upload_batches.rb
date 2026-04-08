class CreateUploadBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :upload_batches, id: :uuid do |t|
      t.references :ceremony, type: :uuid, null: false, foreign_key: true
      t.references :studio, type: :uuid, null: false, foreign_key: true
      t.string :source_type, null: false, default: "import"
      t.integer :total_files, null: false, default: 0
      t.integer :completed_files, null: false, default: 0
      t.integer :failed_files, null: false, default: 0
      t.integer :skipped_files, null: false, default: 0
      t.string :status, null: false, default: "in_progress"
      t.timestamps
    end

    add_reference :photos, :upload_batch, type: :uuid, foreign_key: true
  end
end
