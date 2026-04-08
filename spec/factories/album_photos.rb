FactoryBot.define do
  factory :album_photo do
    association :album
    photo { association(:photo, ceremony: album.ceremony, wedding: album.ceremony.wedding) }
    sort_order { 0 }
  end
end
