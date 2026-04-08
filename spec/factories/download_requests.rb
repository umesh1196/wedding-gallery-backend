FactoryBot.define do
  factory :download_request do
    gallery_session { association(:gallery_session) }
    wedding { gallery_session.wedding }
    ceremony { nil }
    shortlist { nil }
    scope_type { "full_gallery" }
    status { "queued" }
    filename { "wedding-gallery.zip" }
    archive_key { nil }
    error_message { nil }
    completed_at { nil }
    expires_at { nil }

    after(:build) do |download_request|
      if download_request.gallery_session && download_request.wedding != download_request.gallery_session.wedding
        download_request.gallery_session = build(:gallery_session, wedding: download_request.wedding)
      end
    end
  end
end
