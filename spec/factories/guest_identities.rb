FactoryBot.define do
  factory :guest_identity do
    association :wedding
    sequence(:token_digest) { |n| GuestIdentity.digest_token("guest-identity-token-#{n}") }
    visitor_name { "Guest Viewer" }
    normalized_visitor_name { GuestIdentity.normalize_name(visitor_name) }
  end
end
