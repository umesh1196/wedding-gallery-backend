require "rails_helper"

RSpec.describe WeddingArchiveCleanupJob, type: :job do
  describe "#perform" do
    it "deletes old expired wedding storage and marks the wedding archived" do
      wedding = create(:wedding, expires_at: 40.days.ago, is_active: false, archived_at: nil)
      create(:ceremony, wedding: wedding)
      storage_service = instance_double(Storage::Service)
      prefix = Storage::KeyBuilder.wedding_prefix(studio_id: wedding.studio_id, wedding_id: wedding.id)

      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:list).with(prefix: prefix).and_return([ "#{prefix}hero.jpg", "#{prefix}photos/1/original.jpg" ])
      allow(storage_service).to receive(:delete_batch)

      described_class.perform_now

      expect(storage_service).to have_received(:delete_batch).with(keys: [ "#{prefix}hero.jpg", "#{prefix}photos/1/original.jpg" ])
      expect(wedding.reload.archived_at).to be_present
    end

    it "skips weddings that are already archived" do
      wedding = create(:wedding, expires_at: 40.days.ago, is_active: false, archived_at: 1.day.ago)
      storage_service = instance_double(Storage::Service)

      allow(Storage::Service).to receive(:new).and_return(storage_service)
      allow(storage_service).to receive(:list)
      allow(storage_service).to receive(:delete_batch)

      described_class.perform_now

      expect(storage_service).not_to have_received(:list)
      expect(wedding.reload.archived_at).to be_present
    end
  end
end
