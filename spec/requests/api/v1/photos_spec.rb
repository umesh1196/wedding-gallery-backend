require "rails_helper"

RSpec.describe "Api::V1::Photos", type: :request do
  let(:studio) { create(:studio) }
  let(:other_studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio, slug: "priya-arjun") }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "mehendi") }
  let(:other_wedding) { create(:wedding, studio: other_studio, slug: "hidden-wedding") }
  let(:other_ceremony) { create(:ceremony, wedding: other_wedding, slug: "secret-ceremony") }
  let(:connection) { create(:studio_storage_connection, studio: studio, is_default: true) }
  let(:other_connection) { create(:studio_storage_connection, studio: other_studio, is_default: true) }
  let(:token) { JwtService.encode({ studio_id: studio.id }) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/import/discover" do
    it "lists importable files for the studio connection" do
      adapter = instance_double("PhotoSourceAdapter")
      allow(PhotoSources).to receive(:build).and_return(adapter)
      allow(adapter).to receive(:list).and_return(
        [
          {
            source_key: "weddings/mehendi/DSC_0012.jpg",
            filename: "DSC_0012.jpg",
            content_type: "image/jpeg",
            byte_size: 4_500_000,
            etag: "etag-123"
          }
        ]
      )

      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/import/discover",
           params: { connection_id: connection.id, prefix: "mehendi/" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "provider")).to eq("cloudflare_r2")
      expect(response.parsed_body.dig("data", "files", 0, "source_key")).to eq("weddings/mehendi/DSC_0012.jpg")
    end

    it "returns 404 for another studio connection" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/import/discover",
           params: { connection_id: other_connection.id, prefix: "mehendi/" },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/import" do
    let(:files) do
      [
        {
          source_key: "weddings/mehendi/DSC_0012.jpg",
          filename: "DSC_0012.jpg",
          content_type: "image/jpeg",
          byte_size: 4_500_000,
          etag: "etag-123"
        }
      ]
    end

    before do
      adapter = instance_double("PhotoSourceAdapter")
      allow(PhotoSources).to receive(:build).and_return(adapter)
      allow(adapter).to receive(:head).and_return(
        {
          content_type: "image/jpeg",
          byte_size: 4_500_000,
          etag: "etag-123",
          filename: "DSC_0012.jpg"
        }
      )
      allow(JobDispatch).to receive(:enqueue)
    end

    it "creates pending import photos and enqueues import jobs" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/import",
           params: { connection_id: connection.id, files: files },
           headers: headers,
           as: :json

      created_photo = ceremony.photos.order(:created_at).last

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", 0, "ingestion_status")).to eq("queued")
      expect(response.parsed_body.dig("meta", "queued_count")).to eq(1)
      expect(created_photo.source_key).to eq("weddings/mehendi/DSC_0012.jpg")
      expect(JobDispatch).to have_received(:enqueue).with(PhotoImportJob, created_photo.id)
    end

    it "skips duplicates and reports them in meta" do
      create(
        :photo,
        ceremony: ceremony,
        wedding: wedding,
        source_provider: connection.provider,
        source_bucket: connection.bucket,
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123"
      )

      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/import",
           params: { connection_id: connection.id, files: files },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("meta", "queued_count")).to eq(0)
      expect(response.parsed_body.dig("meta", "skipped_count")).to eq(1)
    end
  end

  describe "POST /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/presign" do
    before do
      allow_any_instance_of(Storage::Service).to receive(:presigned_upload_url).and_return("https://upload.example.com/photo-1")
    end

    it "creates direct upload photo records and returns presigned urls" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/presign",
           params: {
             files: [
               { filename: "DSC_0012.jpg", content_type: "image/jpeg", byte_size: 4_500_000 }
             ]
           },
           headers: headers,
           as: :json

      created_photo = ceremony.photos.order(:created_at).last

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", 0, "presigned_url")).to eq("https://upload.example.com/photo-1")
      expect(response.parsed_body.dig("data", 0, "headers", "Content-Type")).to eq("image/jpeg")
      expect(created_photo.ingestion_status).to eq("uploading")
      expect(created_photo.source_provider).to eq("gallery_storage")
    end

    it "returns 400 for an unsupported content type" do
      post "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/presign",
           params: {
             files: [
               { filename: "notes.txt", content_type: "text/plain", byte_size: 100 }
             ]
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("error", "message")).to eq("Unsupported file type")
      expect(response.parsed_body.dig("error", "code")).to eq("bad_request")
    end
  end

  describe "POST /api/v1/photos/:id/confirm" do
    let(:photo) do
      create(
        :photo,
        ceremony: ceremony,
        wedding: wedding,
        ingestion_status: "uploading",
        processing_status: "pending",
        ingested_at: nil,
        processed_at: nil
      )
    end

    before do
      allow_any_instance_of(Storage::Service).to receive(:exists?).and_return(true)
      allow(JobDispatch).to receive(:enqueue)
    end

    it "marks the photo as copied and enqueues processing" do
      post "/api/v1/photos/#{photo.id}/confirm", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(photo.reload.ingestion_status).to eq("copied")
      expect(photo.ingested_at).to be_present
      expect(JobDispatch).to have_received(:enqueue).with(PhotoProcessingJob, photo.id)
    end
  end

  describe "POST /api/v1/photos/:id/retry_import" do
    let(:photo) do
      create(
        :photo,
        ceremony: ceremony,
        wedding: wedding,
        source_provider: "cloudflare_r2",
        source_bucket: connection.bucket,
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123",
        ingestion_status: "failed",
        ingestion_error: "copy failed",
        processing_status: "pending"
      )
    end

    before do
      allow(JobDispatch).to receive(:enqueue)
    end

    it "re-enqueues a failed import" do
      post "/api/v1/photos/#{photo.id}/retry_import", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JobDispatch).to have_received(:enqueue).with(PhotoImportJob, photo.id)
    end
  end

  describe "POST /api/v1/photos/:id/retry_processing" do
    let(:photo) do
      create(
        :photo,
        ceremony: ceremony,
        wedding: wedding,
        ingestion_status: "copied",
        processing_status: "failed",
        processing_error: "vips failed"
      )
    end

    before do
      allow(JobDispatch).to receive(:enqueue)
    end

    it "re-enqueues a failed processing job" do
      post "/api/v1/photos/#{photo.id}/retry_processing", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JobDispatch).to have_received(:enqueue).with(PhotoProcessingJob, photo.id)
    end
  end

  describe "GET /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos" do
    before do
      create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 1, processing_status: "ready")
      create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 2, processing_status: "failed", ingestion_status: "failed")
      create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 3, processing_status: "processing", ingestion_status: "copied")
      create(:photo, ceremony: other_ceremony, wedding: other_wedding, sort_order: 0, processing_status: "ready")
    end

    it "returns ready photos by default for the current studio ceremony" do
      get "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(1)
      expect(response.parsed_body.dig("data", 0, "processing_status")).to eq("ready")
    end

    it "filters by processing status for studio dashboard views" do
      get "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos",
          params: { processing_status: "failed" },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data").size).to eq(1)
      expect(response.parsed_body.dig("data", 0, "processing_status")).to eq("failed")
    end
  end

  describe "DELETE /api/v1/photos/:id" do
    let(:photo) do
      create(
        :photo,
        ceremony: ceremony,
        wedding: wedding,
        original_key: "studios/#{studio.id}/weddings/#{wedding.id}/photos/#{SecureRandom.uuid}/original.jpg",
        thumbnail_key: "studios/#{studio.id}/weddings/#{wedding.id}/photos/#{SecureRandom.uuid}/thumbnail.webp"
      )
    end

    before do
      allow(JobDispatch).to receive(:enqueue)
    end

    it "deletes the photo and enqueues storage cleanup" do
      delete "/api/v1/photos/#{photo.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(Photo.where(id: photo.id)).to be_empty
      expect(JobDispatch).to have_received(:enqueue).with(StorageCleanupJob, [ photo.original_key, photo.thumbnail_key ])
    end
  end

  describe "PATCH /api/v1/weddings/:wedding_slug/ceremonies/:ceremony_slug/photos/reorder" do
    it "reorders photos by id list" do
      first = create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 0)
      second = create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 1)
      third = create(:photo, ceremony: ceremony, wedding: wedding, sort_order: 2)

      patch "/api/v1/weddings/#{wedding.slug}/ceremonies/#{ceremony.slug}/photos/reorder",
            params: { order: [ third.id, first.id, second.id ] },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(ceremony.photos.order(:sort_order).pluck(:id)).to eq([ third.id, first.id, second.id ])
    end
  end

  describe "POST /api/v1/photos/:id/set_cover" do
    it "makes the selected photo the only cover photo for the ceremony" do
      existing_cover = create(:photo, ceremony: ceremony, wedding: wedding, is_cover: true)
      photo = create(:photo, ceremony: ceremony, wedding: wedding, is_cover: false)

      post "/api/v1/photos/#{photo.id}/set_cover", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(photo.reload.is_cover).to be(true)
      expect(existing_cover.reload.is_cover).to be(false)
    end
  end
end
