require "rails_helper"

RSpec.describe PhotoUploads::PresignService do
  let(:studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio) }
  let(:ceremony) { create(:ceremony, wedding: wedding) }
  let(:storage_service) { instance_double(Storage::Service) }
  let(:files) do
    [
      { filename: "DSC_0012.jpg", content_type: "image/jpeg", byte_size: 4_500_000 }
    ]
  end

  before do
    allow(Storage::Service).to receive(:new).and_return(storage_service)
    allow(storage_service).to receive(:presigned_upload_url).and_return("https://upload.example.com/photo-1")
  end

  it "creates direct upload records and returns presigned payloads" do
    result = described_class.new(
      studio: studio,
      wedding: wedding,
      ceremony: ceremony,
      files: files
    ).call

    photo = ceremony.photos.order(:created_at).last

    expect(result[:payload].size).to eq(1)
    expect(result[:payload].first[:presigned_url]).to eq("https://upload.example.com/photo-1")
    expect(result[:upload_batch_id]).to be_present
    expect(photo.ingestion_status).to eq("uploading")
  end

  it "raises for unsupported file types" do
    expect do
      described_class.new(
        studio: studio,
        wedding: wedding,
        ceremony: ceremony,
        files: [ { filename: "notes.txt", content_type: "text/plain", byte_size: 100 } ]
      ).call
    end.to raise_error(ArgumentError, "Unsupported file type")
  end
end
