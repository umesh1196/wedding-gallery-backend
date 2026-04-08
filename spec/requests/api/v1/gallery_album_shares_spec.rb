require "rails_helper"

RSpec.describe "Api::V1::GalleryAlbumShares", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun", allow_download: "all") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:session_record) { create(:gallery_session, wedding: wedding, visitor_name: "Asha") }
  let(:other_session) { create(:gallery_session, wedding: wedding, visitor_name: "Riya") }
  let(:session_token) { "gallery-album-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }
  let!(:first_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 1, width: 4000, height: 2667) }
  let!(:second_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 2, width: 3200, height: 2133) }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(session_token).and_return(session_record.session_token_digest)
    allow_any_instance_of(PhotoUrlBuilder).to receive(:urls).and_return(
      {
        blur: "data:image/webp;base64,abc123",
        thumbnail: "https://cdn.example.com/thumb.webp",
        preview: "https://cdn.example.com/preview.jpg",
        full: "https://cdn.example.com/full.jpg"
      }
    )
  end

  describe "gallery user album curation" do
    let(:album) { create(:album, :user_created, ceremony: ceremony, slug: "our-picks", created_by_gallery_session: session_record) }

    it "adds photos to the current session album" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/photos",
           params: { photo_ids: [ first_photo.id, second_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(album.reload.album_photos.order(:sort_order).pluck(:photo_id)).to eq([ first_photo.id, second_photo.id ])
    end

    it "does not allow mutating another session album" do
      other_album = create(:album, :user_created, ceremony: ceremony, slug: "their-picks", created_by_gallery_session: other_session)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{other_album.slug}/photos",
           params: { photo_ids: [ first_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/share_links" do
    it "creates a share link for a user created album" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "our-picks", created_by_gallery_session: session_record)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/share_links",
           params: { label: "For Mom & Dad", permissions: "view_download" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "token")).to be_present
      expect(response.parsed_body.dig("data", "permissions")).to eq("view_download")
    end
  end

  describe "GET /api/v1/g/albums/shared/:token" do
    it "returns only the shared album shell" do
      album = create(:album, ceremony: ceremony, name: "Studio Picks", slug: "studio-picks")
      create(:album_photo, album: album, photo: first_photo, sort_order: 0)
      share_link = AlbumShareLink.issue!(album: album, created_by_studio: studio, permissions: "view", label: "Family")

      get "/api/v1/g/albums/shared/#{share_link.raw_token}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "album", "slug")).to eq("studio-picks")
      expect(response.parsed_body.dig("data", "permissions")).to eq("view")
    end
  end

  describe "GET /api/v1/g/albums/shared/:token/photos" do
    it "returns only album photos in album order" do
      album = create(:album, ceremony: ceremony, name: "Studio Picks", slug: "studio-picks")
      create(:album_photo, album: album, photo: second_photo, sort_order: 1)
      create(:album_photo, album: album, photo: first_photo, sort_order: 0)
      share_link = AlbumShareLink.issue!(album: album, created_by_studio: studio, permissions: "view_download", label: "Family")

      get "/api/v1/g/albums/shared/#{share_link.raw_token}/photos", params: { limit: 5 }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["id"] }).to eq([ first_photo.id, second_photo.id ])
      expect(response.parsed_body.dig("meta", "permissions")).to eq("view_download")
    end
  end
end
