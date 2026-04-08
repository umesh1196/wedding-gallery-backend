FactoryBot.define do
  factory :share_link do
    association :wedding
    created_by { association(:gallery_session, wedding: wedding) }
    token_digest { ShareLink.digest_token("share-token-#{SecureRandom.hex(8)}") }
    permissions { "view" }
    label { "For Mom & Dad" }
    expires_at { wedding.expires_at }
    revoked_at { nil }
  end
end
