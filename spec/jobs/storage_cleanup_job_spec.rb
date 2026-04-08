require "rails_helper"

RSpec.describe StorageCleanupJob, type: :job do
  describe "#perform" do
    it "deletes keys from gallery storage in batch" do
      storage_service = instance_double(Storage::Service)
      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:delete_batch)

      described_class.perform_now([ "a.jpg", "b.webp" ])

      expect(storage_service).to have_received(:delete_batch).with(keys: [ "a.jpg", "b.webp" ])
    end
  end
end
