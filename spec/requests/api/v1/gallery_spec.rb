require "rails_helper"

RSpec.describe "Api::V1::Gallery", type: :request do
  let(:studio) { create(:studio, studio_name: "Priya Studio", slug: "priya-studio") }
  let(:other_studio) { create(:studio, studio_name: "Other Studio", slug: "other-studio") }
  let(:wedding) do
    create(
      :wedding,
      studio: studio,
      slug: "priya-arjun",
      couple_name: "Priya & Arjun",
      expires_at: 30.days.from_now,
      allow_download: "shortlist",
      allow_comments: true
    )
  end
  let(:other_wedding) { create(:wedding, studio: other_studio, slug: "other-wedding") }
  let!(:haldi) { create(:ceremony, wedding: wedding, name: "Haldi", slug: "haldi", sort_order: 1, photo_count: 2) }
  let!(:reception) { create(:ceremony, wedding: wedding, name: "Reception", slug: "reception", sort_order: 2, photo_count: 1) }

  before do
    Rails.cache.clear
    Gallery::VerifyRateLimiter::FALLBACK_CACHE.clear
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/verify" do
    it "creates a gallery session and returns the gallery shell for a valid password" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "gallerypass123", visitor_name: "Asha" },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "session_token")).to be_present
      expect(response.parsed_body.dig("data", "gallery", "couple_name")).to eq("Priya & Arjun")
      expect(response.parsed_body.dig("data", "gallery", "branding", "slug")).to eq("priya-studio")
      expect(GallerySession.count).to eq(1)
      expect(GallerySession.last.visitor_name).to eq("Asha")
    end

    it "returns 401 for an invalid password" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "wrong-pass" },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "rate limits repeated invalid password attempts" do
      5.times do
        post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
             params: { password: "wrong-pass" },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "wrong-pass" },
           as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("error", "code")).to eq("rate_limited")
    end

    it "resets the verify limiter after a successful password entry" do
      3.times do
        post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
             params: { password: "wrong-pass" },
             as: :json
      end

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "gallerypass123" },
           as: :json

      expect(response).to have_http_status(:ok)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "wrong-pass" },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 410 for an expired gallery" do
      wedding.update!(expires_at: 1.day.ago)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/verify",
           params: { password: "gallerypass123" },
           as: :json

      expect(response).to have_http_status(:gone)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug" do
    it "returns the gallery bootstrap for an authenticated session" do
      session, token = GallerySession.issue_for!(wedding: wedding)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}",
          headers: { "X-Gallery-Token" => token },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "couple_name")).to eq("Priya & Arjun")
      expect(session.reload.last_active_at).to be_within(2.seconds).of(Time.current)
    end

    it "returns 401 for an invalid session token" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}",
          headers: { "X-Gallery-Token" => "invalid-token" },
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when the session token belongs to another wedding" do
      _other_session, token = GallerySession.issue_for!(wedding: other_wedding)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}",
          headers: { "X-Gallery-Token" => token },
          as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies" do
    it "returns ceremonies ordered by sort_order for an authenticated session" do
      _session, token = GallerySession.issue_for!(wedding: wedding)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies",
          headers: { "X-Gallery-Token" => token },
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["slug"] }).to eq(%w[haldi reception])
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos" do
    let!(:first_photo) { create(:photo, ceremony: haldi, wedding: wedding, sort_order: 1, width: 4000, height: 2667) }
    let!(:second_photo) { create(:photo, ceremony: haldi, wedding: wedding, sort_order: 2, width: 3200, height: 2133) }
    let!(:processing_photo) { create(:photo, ceremony: haldi, wedding: wedding, sort_order: 3, processing_status: "processing", processed_at: nil) }
    let!(:comment) { create(:comment, photo: first_photo, gallery_session: create(:gallery_session, wedding: wedding)) }

    before do
      allow_any_instance_of(PhotoUrlBuilder).to receive(:urls).and_return(
        {
          blur: "data:image/webp;base64,abc123",
          thumbnail: "https://cdn.example.com/thumb.webp",
          preview: "https://cdn.example.com/preview.jpg",
          full: "https://cdn.example.com/full.jpg"
        }
      )
    end

    it "returns ready photos only with cursor pagination" do
      _session, token = GallerySession.issue_for!(wedding: wedding)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{haldi.slug}/photos",
          params: { limit: 1 },
          headers: { "X-Gallery-Token" => token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(1)
      expect(response.parsed_body.dig("data", 0, "id")).to eq(first_photo.id)
      expect(response.parsed_body.dig("data", 0, "comment_count")).to eq(1)
      expect(response.parsed_body.dig("meta", "has_more")).to eq(true)
      expect(response.parsed_body.dig("meta", "next_cursor")).to be_present
    end

    it "uses the cursor to fetch the next page" do
      _session, token = GallerySession.issue_for!(wedding: wedding)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{haldi.slug}/photos",
          params: { limit: 1 },
          headers: { "X-Gallery-Token" => token }

      cursor = response.parsed_body.dig("meta", "next_cursor")

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{haldi.slug}/photos",
          params: { limit: 1, cursor: cursor },
          headers: { "X-Gallery-Token" => token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", 0, "id")).to eq(second_photo.id)
      expect(response.parsed_body.dig("meta", "has_more")).to eq(false)
    end
  end
end
