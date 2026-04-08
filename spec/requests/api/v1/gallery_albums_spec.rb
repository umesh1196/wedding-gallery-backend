require "rails_helper"

RSpec.describe "Api::V1::GalleryAlbums", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:session_record) { create(:gallery_session, wedding: wedding, visitor_name: "Asha") }
  let(:other_session) { create(:gallery_session, wedding: wedding, visitor_name: "Riya") }
  let(:session_token) { "gallery-album-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(session_token).and_return(session_record.session_token_digest)
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
