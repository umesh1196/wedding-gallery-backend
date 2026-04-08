require "rails_helper"

RSpec.describe StudioStorageConnection, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:studio_storage_connection)).to be_valid
    end

    it "requires a provider from the supported list" do
      expect(build(:studio_storage_connection, provider: "dropbox")).not_to be_valid
    end

    it "requires a bucket" do
      expect(build(:studio_storage_connection, bucket: nil)).not_to be_valid
    end

    it "allows only one default connection per studio" do
      studio = create(:studio)
      create(:studio_storage_connection, studio: studio, is_default: true)

      duplicate = build(:studio_storage_connection, studio: studio, is_default: true)
      expect(duplicate).not_to be_valid
    end
  end
end
