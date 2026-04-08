require "rails_helper"

RSpec.describe "Api::V1::StorageConnections", type: :request do
  let(:studio) { create(:studio) }
  let(:other_studio) { create(:studio) }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/storage_connections" do
    before do
      create(:studio_storage_connection, studio: studio, label: "Main R2", is_default: true)
      create(:studio_storage_connection, studio: studio, label: "Backup B2", provider: "backblaze_b2")
      create(:studio_storage_connection, studio: other_studio, label: "Other")
    end

    it "lists only the current studio connections" do
      get "/api/v1/storage_connections", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(2)
      expect(response.parsed_body.dig("data").map { |row| row["label"] }).to include("Main R2", "Backup B2")
    end
  end

  describe "POST /api/v1/storage_connections" do
    it "creates a storage connection for the current studio" do
      post "/api/v1/storage_connections",
           params: {
             storage_connection: {
               label: "Main R2",
               provider: "cloudflare_r2",
               bucket: "photographer-archive",
               region: "auto",
               endpoint: "https://example.r2.cloudflarestorage.com",
               access_key: "key",
               secret_key: "secret",
               base_prefix: "weddings/",
               is_default: true
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "label")).to eq("Main R2")
      expect(studio.studio_storage_connections.count).to eq(1)
      expect(studio.studio_storage_connections.last.access_key).to eq("key")
    end

    it "still accepts legacy ciphertext parameter names for backwards compatibility" do
      post "/api/v1/storage_connections",
           params: {
             storage_connection: {
               label: "Legacy Import",
               provider: "cloudflare_r2",
               bucket: "photographer-archive",
               access_key_ciphertext: "legacy-key",
               secret_key_ciphertext: "legacy-secret"
             }
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(studio.studio_storage_connections.last.access_key).to eq("legacy-key")
    end
  end

  describe "PATCH /api/v1/storage_connections/:id" do
    it "updates a current studio connection" do
      connection = create(:studio_storage_connection, studio: studio, label: "Old")

      patch "/api/v1/storage_connections/#{connection.id}",
            params: { storage_connection: { label: "Updated Label", active: false } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "label")).to eq("Updated Label")
      expect(connection.reload.active).to be(false)
    end
  end

  describe "DELETE /api/v1/storage_connections/:id" do
    it "deactivates a connection instead of hard deleting it" do
      connection = create(:studio_storage_connection, studio: studio, active: true)

      delete "/api/v1/storage_connections/#{connection.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(connection.reload.active).to be(false)
    end
  end
end
