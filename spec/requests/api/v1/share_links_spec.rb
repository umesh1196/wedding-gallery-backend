require "rails_helper"

RSpec.describe "Api::V1::ShareLinks", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun", allow_download: "all") }
  let(:gallery_session) { create(:gallery_session, wedding: wedding, visitor_name: "Asha") }
  let(:gallery_token) { "gallery-session-token" }
  let(:gallery_headers) { { "X-Gallery-Token" => gallery_token } }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let!(:photo) { create(:photo, wedding: wedding, ceremony: ceremony) }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(gallery_token).and_return(gallery_session.session_token_digest)
    allow_any_instance_of(Storage::Service).to receive(:presigned_download_url).and_return("https://cdn.example.com/photo.jpg")
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/share" do
    it "creates a share link and returns the raw token once" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/share",
           params: { label: "For Mom & Dad", permissions: "view_like" },
           headers: gallery_headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "token")).to be_present
      expect(response.parsed_body.dig("data", "permissions")).to eq("view_like")
      expect(ShareLink.last.token_digest).to be_present
    end
  end

  describe "GET /api/v1/g/shared/:token" do
    it "redeems a share link and creates a restricted session" do
      share_link = ShareLink.issue!(wedding: wedding, created_by: gallery_session, permissions: "view_like", label: "Family")

      get "/api/v1/g/shared/#{share_link.raw_token}"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "session_token")).to be_present
      restricted_session = GallerySession.order(:created_at).last
      expect(restricted_session.share_link_id).to eq(share_link.id)
      expect(restricted_session.permissions).to eq("view_like")
    end

    it "rejects expired share links" do
      share_link = create(:share_link, wedding: wedding, created_by: gallery_session, expires_at: 1.day.ago)

      get "/api/v1/g/shared/#{share_link.raw_token || 'unused'}"

      expect(response).to have_http_status(:not_found).or have_http_status(:gone)
    end
  end

  describe "permission enforcement for shared sessions" do
    it "allows likes for a view_like shared session" do
      share_link = ShareLink.issue!(wedding: wedding, created_by: gallery_session, permissions: "view_like", label: "Family")
      get "/api/v1/g/shared/#{share_link.raw_token}"
      shared_token = response.parsed_body.dig("data", "session_token")

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/like",
           headers: { "X-Gallery-Token" => shared_token }

      expect(response).to have_http_status(:ok)
    end

    it "blocks likes for a view-only shared session" do
      share_link = ShareLink.issue!(wedding: wedding, created_by: gallery_session, permissions: "view", label: "Family")
      get "/api/v1/g/shared/#{share_link.raw_token}"
      shared_token = response.parsed_body.dig("data", "session_token")

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/like",
           headers: { "X-Gallery-Token" => shared_token }

      expect(response).to have_http_status(:forbidden)
    end

    it "blocks downloads for a view_like shared session" do
      share_link = ShareLink.issue!(wedding: wedding, created_by: gallery_session, permissions: "view_like", label: "Family")
      get "/api/v1/g/shared/#{share_link.raw_token}"
      shared_token = response.parsed_body.dig("data", "session_token")

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/download",
          headers: { "X-Gallery-Token" => shared_token }

      expect(response).to have_http_status(:forbidden)
    end

    it "allows downloads for a view_download shared session when the wedding allows downloads" do
      share_link = ShareLink.issue!(wedding: wedding, created_by: gallery_session, permissions: "view_download", label: "Family")
      get "/api/v1/g/shared/#{share_link.raw_token}"
      shared_token = response.parsed_body.dig("data", "session_token")

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/download",
          headers: { "X-Gallery-Token" => shared_token }

      expect(response).to have_http_status(:ok)
    end
  end
end
