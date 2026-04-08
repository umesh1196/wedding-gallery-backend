class UploadBatchBlueprint < Blueprinter::Base
  identifier :id

  fields :source_type, :total_files, :completed_files, :failed_files,
         :skipped_files, :status, :created_at, :updated_at
end
