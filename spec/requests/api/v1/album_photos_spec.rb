require "rails_helper"

RSpec.describe "Api::V1::AlbumPhotos", type: :request do
  let(:studio) { create(:studio, slug: "priya-studio") }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }
  let(:album) { create(:album, ceremony: ceremony, created_by_studio: studio, slug: "family-picks") }
  let!(:first_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 1) }
  let!(:second_photo) { create(:photo, wedding: wedding, ceremony: ceremony, sort_order: 2) }

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos" do
    it "adds photos to the album" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/photos",
           params: { photo_ids: [ first_photo.id, second_photo.id ] },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "photos_count")).to eq(2)
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/reorder" do
    it "reorders album photos without changing ceremony ordering" do
      create(:album_photo, album: album, photo: first_photo, sort_order: 0)
      create(:album_photo, album: album, photo: second_photo, sort_order: 1)

      patch "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/reorder",
            params: { order: [ second_photo.id, first_photo.id ] },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(album.reload.album_photos.order(:sort_order).pluck(:photo_id)).to eq([ second_photo.id, first_photo.id ])
      expect(ceremony.photos.ready.order(:sort_order).pluck(:id)).to eq([ first_photo.id, second_photo.id ])
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/cover" do
    it "sets the cover from an album photo" do
      create(:album_photo, album: album, photo: first_photo, sort_order: 0)

      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/cover",
           params: { photo_id: first_photo.id },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "cover_photo_id")).to eq(first_photo.id)
    end
  end

  describe "DELETE /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/albums/:album_slug/photos/:photo_id" do
    it "removes a photo from the album" do
      create(:album_photo, album: album, photo: first_photo, sort_order: 0)

      delete "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/albums/#{album.slug}/photos/#{first_photo.id}",
             headers: headers,
             as: :json

      expect(response).to have_http_status(:ok)
      expect(album.reload.photos).to be_empty
    end
  end
end
