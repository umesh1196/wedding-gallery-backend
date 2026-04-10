require "rails_helper"

RSpec.describe "Api::V1::GalleryAlbums", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:guest_identity) { create(:guest_identity, wedding: wedding, visitor_name: "Asha") }
  let(:session_record) { create(:gallery_session, wedding: wedding, visitor_name: "Asha", guest_identity: guest_identity) }
  let(:other_session) { create(:gallery_session, wedding: wedding, visitor_name: "Riya") }
  let(:session_token) { "gallery-album-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }

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

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums" do
    it "creates a user created album for the current gallery session" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums",
           params: { album: { name: "Our Picks", description: "Family selects", album_type: "user_created" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "album_type")).to eq("user_created")
      expect(response.parsed_body.dig("data", "name")).to eq("Our Picks")
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums" do
    it "returns only user created albums owned by the current session" do
      create(:album, :user_created, ceremony: ceremony, name: "Mine", created_by_gallery_session: session_record)
      create(:album, :user_created, ceremony: ceremony, name: "Theirs", created_by_gallery_session: other_session)
      create(:album, ceremony: ceremony, name: "Studio Picks")

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["name"] }).to eq([ "Mine" ])
    end

    it "returns albums created under earlier sessions for the same guest identity" do
      earlier_session = create(:gallery_session, wedding: wedding, visitor_name: "Asha", guest_identity: guest_identity)
      create(:album, :user_created, ceremony: ceremony, name: "Earlier", created_by_gallery_session: earlier_session)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["name"] }).to eq([ "Earlier" ])
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug" do
    it "returns the current session album by slug" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "our-picks", name: "Our Picks", created_by_gallery_session: session_record)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "slug")).to eq("our-picks")
      expect(response.parsed_body.dig("data", "name")).to eq("Our Picks")
    end

    it "returns the current session album by id for compatibility" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "our-picks", created_by_gallery_session: session_record)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.id}",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(album.id)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug/photos" do
    it "returns ordered album photos in guest gallery payload shape" do
      album = create(:album, :user_created, ceremony: ceremony, created_by_gallery_session: session_record)
      later_photo = create(:photo, ceremony: ceremony, original_filename: "later.jpg")
      earlier_photo = create(:photo, ceremony: ceremony, original_filename: "earlier.jpg")
      create(:album_photo, album: album, photo: later_photo, sort_order: 1)
      create(:album_photo, album: album, photo: earlier_photo, sort_order: 0)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/photos",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["id"] }).to eq([ earlier_photo.id, later_photo.id ])
      expect(response.parsed_body.dig("data", 0, "thumbnail_url")).to be_present
      expect(response.parsed_body.dig("meta", "has_more")).to eq(false)
    end

    it "does not return another session album" do
      album = create(:album, :user_created, ceremony: ceremony, created_by_gallery_session: other_session)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/photos",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug" do
    it "updates the current session album" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "our-picks", created_by_gallery_session: session_record)

      patch "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
            params: { album: { name: "Updated Picks" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "name")).to eq("Updated Picks")
    end

    it "does not allow updating another session album" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "their-picks", created_by_gallery_session: other_session)

      patch "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
            params: { album: { name: "Nope" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug" do
    it "deletes the current session album" do
      album = create(:album, :user_created, ceremony: ceremony, slug: "our-picks", created_by_gallery_session: session_record)

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "deleted")).to eq(true)
      expect(Album.exists?(album.id)).to eq(false)
    end
  end
end
