require "rails_helper"

RSpec.describe "Api::V1::GalleryInteractions", type: :request do
  let(:studio) { create(:studio, studio_name: "Priya Studio", slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun", couple_name: "Priya & Arjun") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi", sort_order: 1) }
  let(:session_record) { create(:gallery_session, wedding: wedding) }
  let(:session_token) { "gallery-session-token" }
  let(:headers) { { "X-Gallery-Token" => session_token } }
  let!(:first_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 1, width: 4000, height: 2667) }
  let!(:second_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 2, width: 3200, height: 2133) }

  before do
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

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/photos/:photo_id/like" do
    it "likes a photo idempotently" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{first_photo.id}/like", headers: headers, as: :json
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{first_photo.id}/like", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Like.where(photo: first_photo, gallery_session: session_record).count).to eq(1)
      expect(response.parsed_body.dig("data", "liked")).to eq(true)
    end
  end

  describe "DELETE /api/v1/g/:studio_slug/:wedding_slug/photos/:photo_id/like" do
    it "unlikes a photo idempotently" do
      create(:like, photo: first_photo, gallery_session: session_record)

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{first_photo.id}/like", headers: headers, as: :json
      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/photos/#{first_photo.id}/like", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Like.where(photo: first_photo, gallery_session: session_record)).to be_empty
      expect(response.parsed_body.dig("data", "liked")).to eq(false)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/likes" do
    before do
      create(:like, photo: first_photo, gallery_session: session_record)
    end

    it "lists the current session liked photos" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/likes", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(1)
      expect(response.parsed_body.dig("data", 0, "id")).to eq(first_photo.id)
    end
  end

  describe "POST /api/v1/g/:studio_slug/:wedding_slug/shortlist/photos" do
    it "creates the default shortlist and adds photos" do
      post "/api/v1/g/#{studio.slug}/#{wedding.slug}/shortlist/photos",
           params: { photo_ids: [ first_photo.id, second_photo.id ] },
           headers: headers,
           as: :json

      shortlist = Shortlist.find_by!(gallery_session: session_record, wedding: wedding)

      expect(response).to have_http_status(:ok)
      expect(shortlist.shortlist_photos.order(:sort_order).pluck(:photo_id)).to eq([ first_photo.id, second_photo.id ])
      expect(response.parsed_body.dig("data", "photo_count")).to eq(2)
    end
  end

  describe "DELETE /api/v1/g/:studio_slug/:wedding_slug/shortlist/photos/:photo_id" do
    it "removes a photo from the shortlist" do
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session_record)
      create(:shortlist_photo, shortlist: shortlist, photo: first_photo, sort_order: 0)

      delete "/api/v1/g/#{studio.slug}/#{wedding.slug}/shortlist/photos/#{first_photo.id}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(shortlist.shortlist_photos.reload).to be_empty
      expect(response.parsed_body.dig("data", "photo_count")).to eq(0)
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/shortlist" do
    it "returns the current shortlist photos ordered by sort_order" do
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session_record)
      create(:shortlist_photo, shortlist: shortlist, photo: second_photo, sort_order: 1)
      create(:shortlist_photo, shortlist: shortlist, photo: first_photo, sort_order: 0)

      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/shortlist", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "photos").map { |row| row["id"] }).to eq([ first_photo.id, second_photo.id ])
    end
  end

  describe "PATCH /api/v1/g/:studio_slug/:wedding_slug/shortlist/reorder" do
    it "reorders shortlist photos" do
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session_record)
      create(:shortlist_photo, shortlist: shortlist, photo: first_photo, sort_order: 0)
      create(:shortlist_photo, shortlist: shortlist, photo: second_photo, sort_order: 1)

      patch "/api/v1/g/#{studio.slug}/#{wedding.slug}/shortlist/reorder",
            params: { order: [ second_photo.id, first_photo.id ] },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(shortlist.shortlist_photos.order(:sort_order).pluck(:photo_id)).to eq([ second_photo.id, first_photo.id ])
    end
  end

  describe "GET /api/v1/g/:studio_slug/:wedding_slug/ceremonies/:ceremony_slug/photos" do
    before do
      create(:like, photo: first_photo, gallery_session: session_record)
      shortlist = create(:shortlist, wedding: wedding, gallery_session: session_record)
      create(:shortlist_photo, shortlist: shortlist, photo: second_photo, sort_order: 0)
    end

    it "includes like and shortlist state for the current session" do
      get "/api/v1/g/#{studio.slug}/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos",
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", 0, "is_liked")).to eq(true)
      expect(response.parsed_body.dig("data", 0, "is_shortlisted")).to eq(false)
      expect(response.parsed_body.dig("data", 1, "is_liked")).to eq(false)
      expect(response.parsed_body.dig("data", 1, "is_shortlisted")).to eq(true)
    end
  end
end
