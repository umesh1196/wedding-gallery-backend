require "rails_helper"

RSpec.describe "Api::V1::Weddings", type: :request do
  let(:studio) { create(:studio) }
  let(:other_studio) { create(:studio) }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/weddings" do
    let(:params) do
      {
        wedding: {
          couple_name: "Priya & Arjun",
          wedding_date: "2026-02-15",
          password: "priya2026",
          expires_at: "2026-03-17T00:00:00Z",
          allow_download: "shortlist",
          metadata: { location: "Pune" }
        }
      }
    end

    it "creates a wedding for the current studio" do
      post "/api/v1/weddings", params: params, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "slug")).to eq("priya-arjun")
      expect(studio.weddings.count).to eq(1)
    end

    it "returns 422 for invalid input" do
      post "/api/v1/weddings",
           params: { wedding: { couple_name: "", password: "" } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/weddings" do
    before do
      create(:wedding, studio: studio, couple_name: "Aarav & Siya")
      create(:wedding, studio: studio, couple_name: "Kabir & Meera")
      create(:wedding, studio: other_studio, couple_name: "Other Studio Wedding")
    end

    it "lists only the current studio weddings" do
      get "/api/v1/weddings", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(2)
      expect(response.parsed_body.dig("meta", "count")).to eq(2)
    end
  end

  describe "GET /api/v1/weddings/:slug" do
    it "shows a wedding for the current studio" do
      wedding = create(:wedding, studio: studio, slug: "priya-arjun")
      get "/api/v1/weddings/#{wedding.slug}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "slug")).to eq("priya-arjun")
    end

    it "includes ceremonies in the detail response" do
      wedding = create(:wedding, studio: studio, slug: "priya-arjun")
      create(:ceremony, wedding: wedding, name: "Haldi Ceremony")

      get "/api/v1/weddings/#{wedding.slug}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "ceremonies").first["slug"]).to eq("haldi-ceremony")
    end

    it "returns 404 for another studio wedding" do
      wedding = create(:wedding, studio: other_studio, slug: "hidden-wedding")
      get "/api/v1/weddings/#{wedding.slug}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/weddings/:slug" do
    it "updates a wedding for the current studio" do
      wedding = create(:wedding, studio: studio, slug: "priya-arjun")

      patch "/api/v1/weddings/#{wedding.slug}",
            params: {
              wedding: {
                couple_name: "Priya & Arjun Updated",
                password: "newpass123",
                allow_download: "all",
                metadata: { location: "Mumbai" }
              }
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "slug")).to eq("priya-arjun-updated")
      expect(response.parsed_body.dig("data", "allow_download")).to eq("all")
    end
  end

  describe "DELETE /api/v1/weddings/:slug" do
    it "soft deletes by default" do
      wedding = create(:wedding, studio: studio, slug: "priya-arjun")

      delete "/api/v1/weddings/#{wedding.slug}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(wedding.reload.is_active).to be(false)
    end
  end

  describe "POST /api/v1/weddings/:slug/hero" do
    let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/logo.svg"),
        "image/svg+xml"
      )
    end

    before do
      allow_any_instance_of(WeddingHeroUploadService).to receive(:call).and_return(
        {
          key: "studios/#{studio.id}/weddings/#{wedding.id}/hero.jpg",
          url: "https://cdn.example.com/hero.jpg",
          blur_data_url: "data:image/jpeg;base64,abc123"
        }
      )
    end

    it "uploads a hero image for the current studio wedding" do
      post "/api/v1/weddings/#{wedding.slug}/hero",
           params: { file: file },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "key")).to include("/hero.jpg")
      expect(response.parsed_body.dig("data", "blur_data_url")).to start_with("data:image/jpeg;base64,")
    end

    it "returns 404 for another studio wedding" do
      hidden_wedding = create(:wedding, studio: other_studio, slug: "hidden")

      post "/api/v1/weddings/#{hidden_wedding.slug}/hero",
           params: { file: file },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
