FactoryBot.define do
  factory :upload_batch do
    association :ceremony
    studio { ceremony.wedding.studio }
    source_type { "import" }
    total_files { 3 }
    completed_files { 0 }
    failed_files { 0 }
    skipped_files { 0 }
    status { "in_progress" }
  end
end
