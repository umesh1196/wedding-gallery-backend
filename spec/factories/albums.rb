FactoryBot.define do
  factory :album do
    association :ceremony
    album_type { "studio_curated" }
    name { "Family Favorites" }
    slug { nil }
    description { "Curated album" }
    visibility { "private" }
    photos_count { 0 }
    created_by_studio { nil }
    created_by_gallery_session { nil }
    cover_photo { nil }

    after(:build) do |album|
      if album.studio_curated? && album.created_by_studio.blank? && album.created_by_gallery_session.blank?
        album.created_by_studio = album.ceremony.wedding.studio
      end
    end

    trait :user_created do
      album_type { "user_created" }

      after(:build) do |album|
        if album.created_by_studio.blank? && album.created_by_gallery_session.blank?
          album.created_by_gallery_session = build(:gallery_session, wedding: album.ceremony.wedding)
        end
      end
    end
  end
end
