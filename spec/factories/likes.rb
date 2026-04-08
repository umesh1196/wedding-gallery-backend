FactoryBot.define do
  factory :like do
    association :photo
    gallery_session { create(:gallery_session, wedding: photo.wedding) }
  end
end
