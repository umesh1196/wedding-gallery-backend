require "rails_helper"

RSpec.describe PhotoImports::CreateService do
  let(:studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio) }
  let(:ceremony) { create(:ceremony, wedding: wedding) }
  let(:connection) { create(:studio_storage_connection, studio: studio, is_default: true) }
  let(:source) { instance_double("PhotoSourceAdapter") }
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
    allow(PhotoSources).to receive(:build).with(connection).and_return(source)
    allow(source).to receive(:head).and_return(
      {
        content_type: "image/jpeg",
        byte_size: 4_500_000,
        etag: "etag-123",
        filename: "DSC_0012.jpg"
      }
    )
    allow(JobDispatch).to receive(:enqueue)
  end

  it "creates queued photo imports and enqueues jobs" do
    result = described_class.new(
      studio: studio,
      wedding: wedding,
      ceremony: ceremony,
      connection: connection,
      files: files
    ).call

    photo = ceremony.photos.order(:created_at).last

    expect(result[:photos].size).to eq(1)
    expect(result[:queued_count]).to eq(1)
    expect(result[:skipped_count]).to eq(0)
    expect(photo.source_key).to eq("weddings/mehendi/DSC_0012.jpg")
    expect(JobDispatch).to have_received(:enqueue).with(PhotoImportJob, photo.id)
  end

  it "skips duplicates" do
    create(
      :photo,
      ceremony: ceremony,
      wedding: wedding,
      source_provider: connection.provider,
      source_bucket: connection.bucket,
      source_key: "weddings/mehendi/DSC_0012.jpg",
      source_etag: "etag-123"
    )

    result = described_class.new(
      studio: studio,
      wedding: wedding,
      ceremony: ceremony,
      connection: connection,
      files: files
    ).call

    expect(result[:photos]).to be_empty
    expect(result[:queued_count]).to eq(0)
    expect(result[:skipped_count]).to eq(1)
  end
end
