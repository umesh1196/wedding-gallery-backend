require "rails_helper"

RSpec.describe PhotoImportJob, type: :job do
  describe "#perform" do
    let(:connection) { create(:studio_storage_connection) }
    let(:ceremony) { create(:ceremony, wedding: create(:wedding, studio: connection.studio)) }
    let(:photo) do
      create(
        :photo,
        ceremony: ceremony,
        wedding: ceremony.wedding,
        studio_storage_connection: connection,
        source_provider: connection.provider,
        source_bucket: connection.bucket,
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123",
        ingestion_status: "queued",
        processing_status: "pending"
      )
    end

    it "copies the source file into gallery storage and enqueues processing" do
      adapter = instance_double("PhotoSourceAdapter")
      tempfile = Tempfile.new([ "import", ".jpg" ])
      storage_service = instance_double(Storage::Service)

      allow(PhotoSources).to receive(:build).with(connection).and_return(adapter)
      allow(adapter).to receive(:stream_to_tempfile).with(key: photo.source_key).and_return(tempfile)
      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:upload_file)
      allow(JobDispatch).to receive(:enqueue)

      described_class.perform_now(photo.id)

      expect(photo.reload.ingestion_status).to eq("copied")
      expect(photo.ingested_at).to be_present
      expect(storage_service).to have_received(:upload_file)
      expect(JobDispatch).to have_received(:enqueue).with(PhotoProcessingJob, photo.id)
    ensure
      tempfile.close!
    end
  end
end
