FactoryBot.define do
  factory :photo do
    association :ceremony
    wedding { ceremony.wedding }
    sequence(:original_key) { |n| "studios/#{wedding.studio_id}/weddings/#{wedding.id}/photos/photo-#{n}/original.jpg" }
    thumbnail_key { nil }
    source_provider { "gallery_storage" }
    source_bucket { nil }
    source_key { nil }
    source_etag { nil }
    blur_data_uri { nil }
    width { 0 }
    height { 0 }
    file_size_bytes { 4_500_000 }
    mime_type { "image/jpeg" }
    sequence(:original_filename) { |n| "DSC_#{format('%04d', n)}.jpg" }
    file_extension { "jpg" }
    exif_data { {} }
    sequence(:sort_order) { |n| n }
    is_cover { false }
    ingestion_status { "copied" }
    ingestion_error { nil }
    ingested_at { Time.current }
    processing_status { "ready" }
    processing_error { nil }
    processed_at { Time.current }
  end
end
