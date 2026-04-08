require "rails_helper"

RSpec.describe ZipGenerationJob, type: :job do
  let(:wedding) { create(:wedding) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding) }
  let(:ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let!(:photo) { create(:photo, wedding: wedding, ceremony: ceremony, original_filename: "photo.jpg") }
  let(:download_request) { create(:download_request, wedding: wedding, gallery_session: gallery_session, ceremony: ceremony, scope_type: "ceremony", filename: "haldi.zip") }
  let(:storage_service) { instance_double(Storage::Service) }
  let(:source_tempfile) do
    file = Tempfile.new([ "download-photo", ".jpg" ])
    file.binmode
    file.write("fake-image")
    file.rewind
    file
  end

  before do
    allow(Storage::Service).to receive(:new).and_return(storage_service)
    allow(storage_service).to receive(:download_to_tempfile).and_return(source_tempfile)
    allow(storage_service).to receive(:upload_file)
    allow(storage_service).to receive(:presigned_download_url).and_return("https://cdn.example.com/archive.zip")
  end

  after do
    source_tempfile.close!
  end

  it "builds an archive and marks the request ready" do
    described_class.perform_now(download_request.id)

    expect(download_request.reload.status).to eq("ready")
    expect(download_request.archive_key).to be_present
    expect(download_request.completed_at).to be_present
    expect(download_request.expires_at).to be_present
    expect(storage_service).to have_received(:download_to_tempfile).with(key: photo.original_key)
    expect(storage_service).to have_received(:upload_file)
  end
end
