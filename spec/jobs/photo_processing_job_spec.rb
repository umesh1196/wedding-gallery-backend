require "rails_helper"

RSpec.describe PhotoProcessingJob, type: :job do
  describe "#perform" do
    let(:photo) do
      create(
        :photo,
        ingestion_status: "copied",
        processing_status: "pending",
        thumbnail_key: nil,
        blur_data_uri: nil
      )
    end

    it "generates a thumbnail and marks the photo ready" do
      source_tempfile = Tempfile.new([ "source", ".jpg" ])
      source_tempfile.write("fake")
      source_tempfile.rewind

      storage_service = instance_double(Storage::Service)
      image = double("Vips::Image", width: 5472, height: 3648)
      thumbnail = double("Vips::Thumbnail")
      blur = double("Vips::Blur")

      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:download_to_tempfile).and_return(source_tempfile)
      allow(storage_service).to receive(:upload)
      allow(Vips::Image).to receive(:new_from_file).and_return(image)
      allow(image).to receive(:thumbnail_image).with(300).and_return(thumbnail)
      allow(image).to receive(:thumbnail_image).with(20).and_return(blur)
      allow(thumbnail).to receive(:webpsave_buffer).and_return("thumb-bytes")
      allow(blur).to receive(:webpsave_buffer).and_return("blur-bytes")

      described_class.perform_now(photo.id)

      photo.reload
      expect(photo.processing_status).to eq("ready")
      expect(photo.thumbnail_key).to include("/thumbnail.webp")
      expect(photo.blur_data_uri).to start_with("data:image/webp;base64,")
      expect(photo.width).to eq(5472)
      expect(photo.height).to eq(3648)
    ensure
      source_tempfile.close!
    end
  end
end
