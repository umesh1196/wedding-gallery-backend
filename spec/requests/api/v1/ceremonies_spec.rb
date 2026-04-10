require "rails_helper"

RSpec.describe "Api::V1::Ceremonies", type: :request do
  let(:studio) { create(:studio) }
  let(:other_studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:other_wedding) { create(:wedding, studio: other_studio, slug: "hidden-wedding") }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies" do
    it "creates a ceremony for the current studio wedding" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies",
           params: {
             ceremony: {
               name: "Haldi Ceremony",
               description: "The turmeric ceremony",
               sort_order: 2,
               scheduled_at: "2026-02-08T19:00:00Z"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "slug")).to eq("haldi-ceremony")
      expect(response.parsed_body.dig("data", "cover_image_key")).to be_nil
      expect(response.parsed_body.dig("data", "scheduled_at")).to eq("2026-02-08T19:00:00.000Z")
      expect(wedding.ceremonies.count).to eq(1)
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/ceremonies" do
    before do
      create(:ceremony, wedding: wedding, name: "Reception", sort_order: 2)
      create(:ceremony, wedding: wedding, name: "Haldi", sort_order: 1)
    end

    it "lists ceremonies ordered by sort_order" do
      get "/api/v1/weddings/#{wedding.slug}/ceremonies", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |c| c["slug"] }).to eq([ "haldi", "reception" ])
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/ceremonies/:slug" do
    it "shows a ceremony for the current studio wedding" do
      ceremony = create(:ceremony, wedding: wedding, slug: "haldi-ceremony")

      get "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "slug")).to eq("haldi-ceremony")
      expect(response.parsed_body.dig("data", "scheduled_at")).to eq(ceremony.scheduled_at&.as_json)
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:slug/cover" do
    let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi-ceremony") }
    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/logo.svg"),
        "image/svg+xml"
      )
    end

    before do
      allow_any_instance_of(CeremonyCoverUploadService).to receive(:call).and_return(
        {
          key: "studios/#{studio.id}/weddings/#{wedding.id}/ceremonies/#{ceremony.id}/cover.jpg",
          url: "https://cdn.example.com/cover.jpg"
        }
      )
    end

    it "uploads a ceremony cover for the current studio wedding" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/cover",
           params: { file: file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "key")).to include("/cover.jpg")
      expect(response.parsed_body.dig("data", "url")).to eq("https://cdn.example.com/cover.jpg")
    end

    it "returns 404 for another studio wedding" do
      hidden_ceremony = create(:ceremony, wedding: other_wedding, slug: "secret-ceremony")

      post "/api/v1/weddings/#{other_wedding.slug}/ceremonies/#{hidden_ceremony.slug}/cover",
           params: { file: file },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/ceremonies/:slug" do
    it "updates a ceremony" do
      ceremony = create(:ceremony, wedding: wedding, slug: "haldi")

      patch "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}",
            params: {
              ceremony: {
                name: "Haldi Updated",
                sort_order: 5,
                scheduled_at: "2026-02-08T20:00:00Z"
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "slug")).to eq("haldi-updated")
      expect(response.parsed_body.dig("data", "sort_order")).to eq(5)
      expect(response.parsed_body.dig("data", "scheduled_at")).to eq("2026-02-08T20:00:00.000Z")
    end
  end

  describe "DELETE /api/v1/weddings/:wedding_slug/ceremonies/:slug" do
    it "deletes a ceremony" do
      ceremony = create(:ceremony, wedding: wedding, slug: "haldi")

      delete "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(wedding.ceremonies.where(id: ceremony.id)).to be_empty
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/ceremonies/reorder" do
    it "reorders ceremonies by id list" do
      first = create(:ceremony, wedding: wedding, name: "Engagement", sort_order: 0)
      second = create(:ceremony, wedding: wedding, name: "Haldi", sort_order: 1)
      third = create(:ceremony, wedding: wedding, name: "Reception", sort_order: 2)

      patch "/api/v1/weddings/#{wedding.slug}/ceremonies/reorder",
            params: { order: [ third.id, first.id, second.id ] },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(wedding.ceremonies.order(:sort_order).pluck(:id)).to eq([ third.id, first.id, second.id ])
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/seed" do
    it "seeds the indian_wedding template" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/seed",
           params: { template: "indian_wedding" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data").size).to eq(8)
      expect(wedding.ceremonies.order(:sort_order).pluck(:name)).to eq(
        [
          "Engagement",
          "Haldi",
          "Mehendi",
          "Sangeet",
          "Wedding Ceremony",
          "Reception",
          "Candid Moments",
          "Family Portraits"
        ]
      )
    end

    it "does not reseed when ceremonies already exist" do
      create(:ceremony, wedding: wedding, name: "Existing Ceremony")

      post "/api/v1/weddings/#{wedding.slug}/ceremonies/seed",
           params: { template: "minimal" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("meta", "seeded")).to eq(false)
      expect(wedding.ceremonies.count).to eq(1)
    end
  end

  describe "studio scoping" do
    it "returns 404 for another studio wedding" do
      get "/api/v1/weddings/#{other_wedding.slug}/ceremonies", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
