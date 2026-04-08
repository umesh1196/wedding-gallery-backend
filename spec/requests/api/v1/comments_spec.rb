require "rails_helper"

RSpec.describe "Api::V1::Comments", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun", allow_comments: allow_comments) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding, visitor_name: "Asha") }
  let(:session_token) { "gallery-session-token" }
  let(:gallery_headers) { { "X-Gallery-Token" => session_token } }
  let(:studio_headers) { { "Authorization" => "Bearer #{JwtService.encode({ studio_id: studio.id })}" } }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:photo) { create(:photo, wedding: wedding, ceremony: ceremony) }
  let(:allow_comments) { true }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(session_token).and_return(gallery_session.session_token_digest)
    Rails.cache.clear
    Gallery::CommentRateLimiter::FALLBACK_CACHE.clear if defined?(Gallery::CommentRateLimiter::FALLBACK_CACHE)
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/photos/:photo_id/comments" do
    it "creates a comment and increments the photo comment count" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
           params: { comment: { body: "Love this photo" } },
           headers: gallery_headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "body")).to eq("Love this photo")
      expect(response.parsed_body.dig("data", "visitor_name")).to eq("Asha")
      expect(photo.reload.comments_count).to eq(1)
    end

    it "returns 403 when comments are disabled" do
      wedding.update!(allow_comments: false)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
           params: { comment: { body: "Hello" } },
           headers: gallery_headers,
           as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 400 for a blank comment" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
           params: { comment: { body: "   " } },
           headers: gallery_headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rate limits repeated comment creation" do
      5.times do |index|
        post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
             params: { comment: { body: "Comment #{index}" } },
             headers: gallery_headers,
             as: :json

        expect(response).to have_http_status(:created)
      end

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
           params: { comment: { body: "Comment 6" } },
           headers: gallery_headers,
           as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.parsed_body.dig("error", "code")).to eq("rate_limited")
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/photos/:photo_id/comments" do
    let!(:older) { create(:comment, photo: photo, gallery_session: gallery_session, body: "Older", created_at: 2.days.ago) }
    let!(:newer) { create(:comment, photo: photo, gallery_session: gallery_session, body: "Newer", created_at: 1.day.ago) }

    it "returns comments newest first" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{photo.id}/comments",
          headers: gallery_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["body"] }).to eq([ "Newer", "Older" ])
    end
  end

  describe "DELETE /api/v1/g/:studio_slug/:wedding_slug/comments/:id" do
    it "allows users to delete their own comments" do
      comment = create(:comment, photo: photo, gallery_session: gallery_session)

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/comments/#{comment.id}",
             headers: gallery_headers

      expect(response).to have_http_status(:ok)
      expect(photo.reload.comments_count).to eq(0)
    end

    it "does not allow users to delete another session's comment" do
      other_comment = create(:comment, photo: photo, gallery_session: create(:gallery_session, wedding: wedding))

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/comments/#{other_comment.id}",
             headers: gallery_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/weddings/:slug/comments" do
    let!(:comment) { create(:comment, photo: photo, gallery_session: gallery_session, body: "Family favorite") }

    it "returns wedding comments for the studio with photo and ceremony context" do
      get "/api/v1/weddings/#{wedding.slug}/comments",
          headers: studio_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", 0, "body")).to eq("Family favorite")
      expect(response.parsed_body.dig("data", 0, "photo_id")).to eq(photo.id)
      expect(response.parsed_body.dig("data", 0, "ceremony_slug")).to eq(ceremony.slug)
    end
  end
end
