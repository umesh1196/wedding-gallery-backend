FactoryBot.define do
  factory :ceremony do
    association :wedding
    name { "Haldi Ceremony" }
    description { "The turmeric ceremony" }
    sequence(:sort_order) { |n| n }
    photo_count { 0 }
    video_count { 0 }
  end
end
