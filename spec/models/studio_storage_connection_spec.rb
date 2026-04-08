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

  describe "encryption" do
    it "encrypts stored credentials while exposing decrypted values through the model" do
      connection = create(
        :studio_storage_connection,
        access_key: "plain-access-key",
        secret_key: "plain-secret-key"
      )

      expect(connection.reload.access_key).to eq("plain-access-key")
      expect(connection.reload.secret_key).to eq("plain-secret-key")
      expect(connection.access_key_ciphertext).to be_present
      expect(connection.secret_key_ciphertext).to be_present

      raw_access_key = connection.read_attribute_before_type_cast("access_key_ciphertext")
      raw_secret_key = connection.read_attribute_before_type_cast("secret_key_ciphertext")

      expect(raw_access_key).not_to include("plain-access-key")
      expect(raw_secret_key).not_to include("plain-secret-key")
    end
  end
end
