require "rails_helper"

RSpec.describe JobDispatch do
  describe ".enqueue" do
    it "enqueues the job normally when the backend is available" do
      allow(PhotoProcessingJob).to receive(:perform_later)

      described_class.enqueue(PhotoProcessingJob, "photo-1")

      expect(PhotoProcessingJob).to have_received(:perform_later).with("photo-1")
    end

    it "falls back to perform_now in development/test when queue enqueue fails" do
      allow(PhotoProcessingJob).to receive(:perform_later).and_raise(ActiveRecord::StatementInvalid.new("missing queue table"))
      allow(PhotoProcessingJob).to receive(:perform_now)

      described_class.enqueue(PhotoProcessingJob, "photo-1")

      expect(PhotoProcessingJob).to have_received(:perform_now).with("photo-1")
    end
  end
end
