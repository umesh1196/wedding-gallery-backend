require "rails_helper"

RSpec.describe "Api::V1::GalleryDownloads", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun", allow_download: allow_download) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding) }
  let(:session_token) { "gallery-session-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let!(:photo) { create(:photo, wedding: wedding, ceremony: ceremony, original_filename: "photo.jpg") }
  let(:allow_download) { "all" }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(session_token).and_return(gallery_session.session_token_digest)
    allow_any_instance_of(Storage::Service).to receive(:presigned_download_url).and_return("https://cdn.example.com/photo.jpg")
    allow(JobDispatch).to receive(:enqueue)
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/photos/:photo_id/download" do
    it "returns a signed url when downloads are fully allowed" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/download", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "download_url")).to eq("https://cdn.example.com/photo.jpg")
      expect(response.parsed_body.dig("data", "filename")).to eq("photo.jpg")
    end

    context "when downloads are shortlist-only" do
      let(:allow_download) { "shortlist" }

      it "blocks photos that are not shortlisted by the current session" do
        get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/download", headers: headers

        expect(response).to have_http_status(:forbidden)
      end

      it "allows photos in the current session shortlist" do
        shortlist = create(:shortlist, wedding: wedding, gallery_session: gallery_session)
        create(:shortlist_photo, shortlist: shortlist, photo: photo)

        get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/download", headers: headers

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/downloads" do
    it "creates a ceremony archive request and enqueues the zip job" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/downloads",
           params: { type: "ceremony", ceremony_slug: ceremony.slug },
           headers: headers,
           as: :json

      request_record = DownloadRequest.order(:created_at).last

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body.dig("data", "status")).to eq("queued")
      expect(request_record.scope_type).to eq("ceremony")
      expect(JobDispatch).to have_received(:enqueue).with(ZipGenerationJob, request_record.id)
    end

    it "blocks full gallery bulk downloads when permission is shortlist-only" do
      wedding.update!(allow_download: "shortlist")

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/downloads",
           params: { type: "full_gallery" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/downloads/:id" do
    let(:download_request) { create(:download_request, wedding: wedding, gallery_session: gallery_session, scope_type: "full_gallery", status: "ready", archive_key: "archive.zip", expires_at: 24.hours.from_now) }

    before do
      allow_any_instance_of(Storage::Service).to receive(:presigned_download_url).and_return("https://cdn.example.com/archive.zip")
    end

    it "returns the owner session download request status" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/downloads/#{download_request.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "status")).to eq("ready")
      expect(response.parsed_body.dig("data", "download_url")).to eq("https://cdn.example.com/archive.zip")
    end

    it "does not expose another session's download request" do
      other_request = create(:download_request, wedding: wedding, gallery_session: create(:gallery_session, wedding: wedding))

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/downloads/#{other_request.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
