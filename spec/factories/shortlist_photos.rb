FactoryBot.define do
  factory :shortlist_photo do
    association :shortlist
    photo { create(:photo, wedding: shortlist.wedding, ceremony: create(:ceremony, wedding: shortlist.wedding)) }
    sequence(:sort_order) { |n| n }
    note { nil }
  end
end
