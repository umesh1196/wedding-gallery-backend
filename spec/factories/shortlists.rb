FactoryBot.define do
  factory :shortlist do
    association :wedding
    gallery_session { create(:gallery_session, wedding: wedding) }
    name { "My Shortlist" }
  end
end
