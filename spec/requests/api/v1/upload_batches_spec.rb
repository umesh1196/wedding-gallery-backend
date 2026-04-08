require "rails_helper"

RSpec.describe "Api::V1::UploadBatches", type: :request do
  let(:studio) { create(:studio) }
  let(:other_studio) { create(:studio) }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:ceremony) { create(:ceremony, wedding: create(:wedding, studio: studio)) }

  describe "GET /api/v1/upload_batches/:id" do
    it "returns batch progress for the current studio" do
      batch = create(:upload_batch, ceremony: ceremony, studio: studio, total_files: 10, completed_files: 7, failed_files: 1, skipped_files: 1)

      get "/api/v1/upload_batches/#{batch.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "total_files")).to eq(10)
      expect(response.parsed_body.dig("data", "completed_files")).to eq(7)
      expect(response.parsed_body.dig("data", "failed_files")).to eq(1)
      expect(response.parsed_body.dig("data", "skipped_files")).to eq(1)
    end

    it "returns 404 for another studio batch" do
      other_batch = create(:upload_batch, ceremony: create(:ceremony, wedding: create(:wedding, studio: other_studio)), studio: other_studio)

      get "/api/v1/upload_batches/#{other_batch.id}", headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
