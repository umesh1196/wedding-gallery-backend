require "rails_helper"

RSpec.describe "Api::V1::GalleryPrintSelectionBuckets", type: :request do
  let(:studio) { create(:studio, slug: "mppf-photography") }
  let(:wedding) { create(:wedding, studio: studio, slug: "umesh-and-shruti") }
  let(:engagement) { create(:ceremony, wedding: wedding, slug: "engagement") }
  let(:haldi) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:guest_identity) { create(:guest_identity, wedding: wedding, visitor_name: "Umesh") }
  let(:session_record) { create(:gallery_session, wedding: wedding, visitor_name: "Umesh", guest_identity: guest_identity) }
  let(:session_token) { "print-selection-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }

  before do
    allow(GallerySession).to receive(:digest_token).and_call_original
    allow(GallerySession).to receive(:digest_token).with(session_token).and_return(session_record.session_token_digest)
    allow_any_instance_of(PhotoUrlBuilder).to receive(:urls).and_return(
      {
        blur: "data:image/webp;base64,abc123",
        thumbnail: "https://cdn.example.com/thumb.webp",
        preview: "https://cdn.example.com/preview.jpg",
        full: "https://cdn.example.com/full.jpg"
      }
    )
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/print_selection_buckets" do
    it "returns all wedding-level print buckets" do
      create(:print_selection_bucket, wedding: wedding, name: "Bride Side Album")
      create(:print_selection_bucket, wedding: wedding, name: "Groom Side Album")

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["name"] }).to eq([ "Bride Side Album", "Groom Side Album" ])
    end
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/print_selection_buckets/:slug/photos" do
    it "adds photos from different chapters into the same bucket" do
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 5)
      engagement_photo = create(:photo, wedding: wedding, ceremony: engagement)
      haldi_photo = create(:photo, wedding: wedding, ceremony: haldi)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
           params: { photo_ids: [ engagement_photo.id, haldi_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "selected_count")).to eq(2)
    end

    it "blocks additions when the hard limit is reached" do
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 1)
      existing_photo = create(:photo, wedding: wedding, ceremony: engagement)
      create(:print_selection_photo, print_selection_bucket: bucket, photo: existing_photo)
      next_photo = create(:photo, wedding: wedding, ceremony: haldi)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
           params: { photo_ids: [ next_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("selection_limit_reached")
    end

    it "rejects photos outside the wedding" do
      other_wedding = create(:wedding, studio: studio)
      other_ceremony = create(:ceremony, wedding: other_wedding)
      other_photo = create(:photo, wedding: other_wedding, ceremony: other_ceremony)
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 4)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
           params: { photo_ids: [ other_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("photo_not_in_wedding")
    end

    it "blocks changes on a locked bucket" do
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 4, locked_at: Time.current)
      photo = create(:photo, wedding: wedding, ceremony: engagement)

      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
           params: { photo_ids: [ photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("error", "code")).to eq("print_bucket_locked")
    end
  end

  describe "DELETE /api/v1/g/:studio_slug/:wedding_slug/print_selection_buckets/:slug/photos/:photo_id" do
    it "removes a selected photo while unlocked" do
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 4)
      photo = create(:photo, wedding: wedding, ceremony: engagement)
      create(:print_selection_photo, print_selection_bucket: bucket, photo: photo)

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos/#{photo.id}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "selected_count")).to eq(0)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/print_selection_buckets/:slug/photos" do
    it "returns selected photos across chapters in gallery payload shape" do
      bucket = create(:print_selection_bucket, wedding: wedding, selection_limit: 4)
      engagement_photo = create(:photo, wedding: wedding, ceremony: engagement)
      haldi_photo = create(:photo, wedding: wedding, ceremony: haldi)
      create(:print_selection_photo, print_selection_bucket: bucket, photo: engagement_photo, created_at: 1.minute.ago)
      create(:print_selection_photo, print_selection_bucket: bucket, photo: haldi_photo, created_at: Time.current)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["ceremony_slug"] }).to eq([ "engagement", "haldi" ])
    end
  end
end
