FactoryBot.define do
  factory :gallery_session do
    association :wedding
    guest_identity { nil }
    sequence(:session_token_digest) { |n| GallerySession.digest_token("gallery-session-token-#{n}") }
    visitor_name { "Guest Viewer" }
    role { "guest" }
    last_ip { "127.0.0.1" }
    last_user_agent { "RSpec" }
    last_active_at { Time.current }
    revoked_at { nil }
    permissions { nil }
    share_link { nil }
  end
end
