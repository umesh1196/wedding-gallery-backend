require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/signup" do
    let(:valid_params) do
      { studio: { email: "priya@studio.com", password: "securepass", studio_name: "Priya Photography" } }
    end

    it "creates a studio and returns a token" do
      post "/api/v1/auth/signup", params: valid_params, as: :json
      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["success"]).to be true
      expect(json["data"]["token"]).to be_present
      expect(json["data"]["studio"]["slug"]).to eq("priya-photography")
    end

    it "returns 422 for duplicate email" do
      create(:studio, email: "priya@studio.com")
      post "/api/v1/auth/signup", params: valid_params, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 for missing studio_name" do
      post "/api/v1/auth/signup",
           params: { studio: { email: "x@x.com", password: "pass" } },
           as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:studio) { create(:studio, email: "priya@studio.com", password: "securepass") }

    it "returns a token for valid credentials" do
      post "/api/v1/auth/login",
           params: { studio: { email: "priya@studio.com", password: "securepass" } },
           as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["data"]["token"]).to be_present
    end

    it "returns 401 for wrong password" do
      post "/api/v1/auth/login",
           params: { studio: { email: "priya@studio.com", password: "wrong" } },
           as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 for unknown email" do
      post "/api/v1/auth/login",
           params: { studio: { email: "nobody@example.com", password: "pass" } },
           as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/auth/me" do
    let!(:studio) { create(:studio) }

    it "returns current studio profile with valid token" do
      token = JwtService.encode({ studio_id: studio.id })
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }, as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["data"]["id"]).to eq(studio.id)
    end

    it "returns 401 without a token" do
      get "/api/v1/auth/me", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an expired token" do
      token = JwtService.encode({ studio_id: studio.id }, exp: 1.second.ago)
      get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
