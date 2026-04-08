require "rails_helper"

RSpec.describe "Api::V1::Shortlists", type: :request do
  let(:studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:other_wedding) { create(:wedding, studio: studio, slug: "other-wedding") }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/weddings/:wedding_slug/shortlists" do
    it "returns shortlist summaries for the wedding" do
      session = create(:gallery_session, wedding: wedding, visitor_name: "Aditi")
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session)
      photo = create(:photo, wedding: wedding, ceremony: create(:ceremony, wedding: wedding))
      create(:shortlist_photo, shortlist: shortlist, photo: photo, sort_order: 0)
      create(:shortlist, wedding: other_wedding, gallery_session: create(:gallery_session, wedding: other_wedding, visitor_name: "Else"))

      get "/api/v1/weddings/#{wedding.slug}/shortlists", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(1)
      expect(response.parsed_body.dig("data", 0, "visitor_name")).to eq("Aditi")
      expect(response.parsed_body.dig("data", 0, "photo_count")).to eq(1)
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/shortlists/:id" do
    it "returns shortlist detail for the wedding" do
      session = create(:gallery_session, wedding: wedding, visitor_name: "Aditi")
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session)
      first_photo = create(:photo, wedding: wedding, ceremony: create(:ceremony, wedding: wedding), sort_order: 1)
      second_photo = create(:photo, wedding: wedding, ceremony: create(:ceremony, wedding: wedding), sort_order: 2)
      create(:shortlist_photo, shortlist: shortlist, photo: second_photo, sort_order: 1, note: "Album pick")
      create(:shortlist_photo, shortlist: shortlist, photo: first_photo, sort_order: 0)

      get "/api/v1/weddings/#{wedding.slug}/shortlists/#{shortlist.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "id")).to eq(shortlist.id)
      expect(response.parsed_body.dig("data", "photos").map { |row| row["id"] }).to eq([ first_photo.id, second_photo.id ])
      expect(response.parsed_body.dig("data", "photos", 1, "note")).to eq("Album pick")
    end
  end
end
