require "rails_helper"

RSpec.describe Photo, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:photo)).to be_valid
    end

    it "requires an original_key" do
      expect(build(:photo, original_key: nil)).not_to be_valid
    end

    it "requires a supported source provider" do
      expect(build(:photo, source_provider: "google_drive")).not_to be_valid
    end

    it "requires a supported ingestion status" do
      expect(build(:photo, ingestion_status: "done")).not_to be_valid
    end

    it "requires a supported processing status" do
      expect(build(:photo, processing_status: "complete")).not_to be_valid
    end

    it "prevents duplicate imports for the same ceremony and source object" do
      ceremony = create(:ceremony)
      create(
        :photo,
        ceremony: ceremony,
        wedding: ceremony.wedding,
        source_provider: "cloudflare_r2",
        source_bucket: "photographer-archive",
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123"
      )

      duplicate = build(
        :photo,
        ceremony: ceremony,
        wedding: ceremony.wedding,
        source_provider: "cloudflare_r2",
        source_bucket: "photographer-archive",
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123"
      )

      expect(duplicate).not_to be_valid
    end

    it "allows the same source key when the etag has changed" do
      ceremony = create(:ceremony)
      create(
        :photo,
        ceremony: ceremony,
        wedding: ceremony.wedding,
        source_provider: "cloudflare_r2",
        source_bucket: "photographer-archive",
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-123"
      )

      changed = build(
        :photo,
        ceremony: ceremony,
        wedding: ceremony.wedding,
        source_provider: "cloudflare_r2",
        source_bucket: "photographer-archive",
        source_key: "weddings/mehendi/DSC_0012.jpg",
        source_etag: "etag-456"
      )

      expect(changed).to be_valid
    end
  end
end
