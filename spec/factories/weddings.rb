FactoryBot.define do
  factory :wedding do
    association :studio
    couple_name { "Priya & Arjun" }
    wedding_date { Date.new(2026, 2, 15) }
    password { "gallerypass123" }
    expires_at { 30.days.from_now }
    allow_download { "shortlist" }
    allow_comments { true }
    is_active { true }
    total_photos { 0 }
    total_videos { 0 }
    metadata { {} }
  end
end
