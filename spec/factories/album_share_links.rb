FactoryBot.define do
  factory :album_share_link do
    association :album
    created_by_studio { album.created_by_studio }
    created_by_gallery_session { album.created_by_gallery_session }
    token_digest { AlbumShareLink.digest_token("album-share-#{SecureRandom.hex(8)}") }
    permissions { "view" }
    label { "For Family" }
    expires_at { album.wedding.expires_at }
    revoked_at { nil }
  end
end
