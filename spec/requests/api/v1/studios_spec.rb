require "rails_helper"

RSpec.describe "Api::V1::Studios", type: :request do
  let(:studio) { create(:studio) }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }

  describe "PATCH /api/v1/studio" do
    it "updates studio profile and branding fields" do
      patch "/api/v1/studio",
            params: {
              studio: {
                studio_name: "Updated Studio",
                slug: "updated-brand",
                phone: "+919999999999",
                color_primary: "#112233",
                color_accent: "#c0ffee",
                font_heading: "Lora",
                font_body: "DM Sans",
                logo_url: "https://cdn.example.com/logo.png",
                watermark_url: "https://cdn.example.com/watermark.png",
                watermark_opacity: 0.55
              }
            },
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body

      expect(json["data"]["studio_name"]).to eq("Updated Studio")
      expect(json["data"]["slug"]).to eq("updated-brand")
      expect(json["data"]["color_primary"]).to eq("#112233")
      expect(json["data"]["font_heading"]).to eq("Lora")
      expect(json["data"]["watermark_opacity"]).to eq("0.55")
    end

    it "returns 401 without authentication" do
      patch "/api/v1/studio", params: { studio: { studio_name: "Updated Studio" } }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 when slug conflicts" do
      create(:studio, slug: "taken-slug", email: "other@example.com")

      patch "/api/v1/studio",
            params: { studio: { slug: "taken slug" } },
            headers: { "Authorization" => "Bearer #{token}" },
            as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/studio/logo" do
    let(:storage_service) { instance_double(Storage::Service) }
    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/logo.svg"),
        "image/svg+xml"
      )
    end

    before do
      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:upload)
      allow(storage_service).to receive(:presigned_download_url).and_return("https://cdn.example.com/logo.svg")
    end

    it "uploads a logo and stores the object key" do
      post "/api/v1/studio/logo",
           params: { file: file },
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(storage_service).to have_received(:upload)

      expect(studio.reload.logo_key).to eq("studios/#{studio.id}/logo.svg")
      expect(response.parsed_body.dig("data", "url")).to eq("https://cdn.example.com/logo.svg")
    end

    it "rejects invalid file types" do
      invalid_file = Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/invalid.txt"),
        "text/plain"
      )

      post "/api/v1/studio/logo",
           params: { file: invalid_file },
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/studio/watermark" do
    let(:storage_service) { instance_double(Storage::Service) }
    let(:file) do
      Rack::Test::UploadedFile.new(
        Rails.root.join("spec/fixtures/files/logo.svg"),
        "image/svg+xml"
      )
    end

    before do
      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:upload)
      allow(storage_service).to receive(:presigned_download_url).and_return("https://cdn.example.com/watermark.svg")
    end

    it "uploads a watermark and stores the object key" do
      post "/api/v1/studio/watermark",
           params: { file: file },
           headers: { "Authorization" => "Bearer #{token}" }

      expect(response).to have_http_status(:ok)
      expect(studio.reload.watermark_key).to eq("studios/#{studio.id}/watermark.svg")
      expect(response.parsed_body.dig("data", "url")).to eq("https://cdn.example.com/watermark.svg")
    end

    it "requires authentication" do
      post "/api/v1/studio/watermark", params: { file: file }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
