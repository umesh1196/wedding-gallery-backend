require "rails_helper"

RSpec.describe "Api::V1::Albums", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:other_studio) { create(:studio, slug: "other-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:other_wedding) { create(:wedding, studio: other_studio, slug: "other-wedding") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums" do
    it "creates a studio curated album" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums",
           params: { album: { name: "Bride Family", description: "Curated", album_type: "studio_curated" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "album_type")).to eq("studio_curated")
      expect(response.parsed_body.dig("data", "name")).to eq("Bride Family")
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums" do
    it "returns only studio curated albums for the ceremony" do
      create(:album, ceremony: ceremony, name: "Studio Picks", created_by_studio: studio)
      create(:album, :user_created, ceremony: ceremony, name: "Private Picks")

      get "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["name"] }).to eq([ "Studio Picks" ])
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug" do
    it "updates a studio curated album" do
      album = create(:album, ceremony: ceremony, slug: "studio-picks", created_by_studio: studio)

      patch "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
            params: { album: { name: "Updated Studio Picks" } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "name")).to eq("Updated Studio Picks")
    end
  end

  describe "DELETE /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:slug" do
    it "deletes a studio curated album" do
      album = create(:album, ceremony: ceremony, slug: "studio-picks", created_by_studio: studio)

      delete "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "deleted")).to eq(true)
      expect(Album.exists?(album.id)).to eq(false)
    end
  end
end
