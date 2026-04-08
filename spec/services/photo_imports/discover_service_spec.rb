require "rails_helper"

RSpec.describe PhotoImports::DiscoverService do
  let(:studio) { create(:studio) }
  let(:wedding) { create(:wedding, studio: studio) }
  let(:ceremony) { create(:ceremony, wedding: wedding) }
  let(:connection) { create(:studio_storage_connection, studio: studio, base_prefix: "weddings/") }
  let(:source) { instance_double("PhotoSourceAdapter") }

  before do
    allow(PhotoSources).to receive(:build).with(connection).and_return(source)
    allow(source).to receive(:list).and_return(
      [
        {
          source_key: "weddings/haldi/DSC_0012.jpg",
          filename: "DSC_0012.jpg",
          content_type: "image/jpeg",
          byte_size: 4_500_000,
          etag: "etag-123"
        }
      ]
    )
  end

  it "returns the normalized prefix and files from the selected source" do
    result = described_class.new(connection: connection, prefix: "haldi/").call

    expect(result[:connection_id]).to eq(connection.id)
    expect(result[:prefix]).to eq("weddings/haldi/")
    expect(result[:files].first[:source_key]).to eq("weddings/haldi/DSC_0012.jpg")
  end
end
