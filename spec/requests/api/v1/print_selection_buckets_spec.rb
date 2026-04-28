require "rails_helper"

RSpec.describe "Api::V1::PrintSelectionBuckets", type: :request do
  let(:studio) { create(:studio, slug: "mppf-photography") }
  let(:other_studio) { create(:studio, slug: "other-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "umesh-and-shruti") }
  let(:other_wedding) { create(:wedding, studio: other_studio, slug: "other-wedding") }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/weddings/:wedding_slug/print_selection_buckets" do
    it "creates a wedding-level print bucket" do
      post "/api/v1/weddings/#{wedding.slug}/print_selection_buckets",
           params: { print_selection_bucket: { name: "Bride Side Album", selection_limit: 120 } },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "name")).to eq("Bride Side Album")
      expect(response.parsed_body.dig("data", "selection_limit")).to eq(120)
      expect(response.parsed_body.dig("data", "selected_count")).to eq(0)
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/print_selection_buckets" do
    it "returns the wedding print buckets in order" do
      create(:print_selection_bucket, wedding: wedding, name: "Bride Side Album", sort_order: 1)
      create(:print_selection_bucket, wedding: wedding, name: "Groom Side Album", sort_order: 0)
      create(:print_selection_bucket, wedding: other_wedding, name: "Other")

      get "/api/v1/weddings/#{wedding.slug}/print_selection_buckets", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").map { |row| row["name"] }).to eq([ "Groom Side Album", "Bride Side Album" ])
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/print_selection_buckets/:slug" do
    it "updates bucket name and limit" do
      bucket = create(:print_selection_bucket, wedding: wedding, slug: "bride-side")

      patch "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}",
            params: { print_selection_bucket: { name: "Bride Album", selection_limit: 140 } },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "name")).to eq("Bride Album")
      expect(response.parsed_body.dig("data", "selection_limit")).to eq(140)
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/print_selection_buckets/:slug/photos" do
    it "returns selected photos for admin inspection" do
      ceremony = create(:ceremony, wedding: wedding)
      bucket = create(:print_selection_bucket, wedding: wedding)
      photo = create(:photo, wedding: wedding, ceremony: ceremony, original_filename: "family.jpg")
      create(:print_selection_photo, print_selection_bucket: bucket, photo: photo)

      get "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/photos",
          headers: headers,
          as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", 0, "original_filename")).to eq("family.jpg")
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/print_selection_buckets/:slug/lock" do
    it "locks the bucket" do
      bucket = create(:print_selection_bucket, wedding: wedding)

      post "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/lock",
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "locked")).to eq(true)
    end
  end

  describe "DELETE /api/v1/weddings/:wedding_slug/print_selection_buckets/:slug/lock" do
    it "unlocks the bucket" do
      bucket = create(:print_selection_bucket, wedding: wedding, locked_at: Time.current)

      delete "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}/lock",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "locked")).to eq(false)
    end
  end

  describe "DELETE /api/v1/weddings/:wedding_slug/print_selection_buckets/:slug" do
    it "deletes an empty bucket" do
      bucket = create(:print_selection_bucket, wedding: wedding)

      delete "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(PrintSelectionBucket.exists?(bucket.id)).to eq(false)
    end

    it "does not delete a non-empty bucket" do
      ceremony = create(:ceremony, wedding: wedding)
      bucket = create(:print_selection_bucket, wedding: wedding)
      photo = create(:photo, wedding: wedding, ceremony: ceremony)
      create(:print_selection_photo, print_selection_bucket: bucket, photo: photo)

      delete "/api/v1/weddings/#{wedding.slug}/print_selection_buckets/#{bucket.slug}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body.dig("error", "code")).to eq("bucket_not_empty")
    end
  end
end
