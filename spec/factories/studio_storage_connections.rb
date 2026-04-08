FactoryBot.define do
  factory :studio_storage_connection do
    association :studio
    sequence(:label) { |n| "Primary Import #{n}" }
    provider { "cloudflare_r2" }
    account_id { "acct-123" }
    bucket { "photographer-archive" }
    region { "auto" }
    endpoint { "https://example.r2.cloudflarestorage.com" }
    access_key_ciphertext { "encrypted-access-key" }
    secret_key_ciphertext { "encrypted-secret-key" }
    base_prefix { "weddings/" }
    is_default { false }
    active { true }
  end
end
