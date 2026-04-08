FactoryBot.define do
  factory :comment do
    photo { association(:photo) }
    gallery_session { association(:gallery_session, wedding: photo.wedding) }
    body { "Beautiful moment" }
    visitor_name_snapshot { "Guest Viewer" }

    after(:build) do |comment|
      if comment.gallery_session && comment.photo && comment.gallery_session.wedding_id != comment.photo.wedding_id
        comment.gallery_session = build(:gallery_session, wedding: comment.photo.wedding)
      end
    end
  end
end
