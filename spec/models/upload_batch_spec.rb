require "rails_helper"

RSpec.describe UploadBatch, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:upload_batch)).to be_valid
    end

    it "requires a supported source type" do
      expect(build(:upload_batch, source_type: "folder_sync")).not_to be_valid
    end

    it "requires a supported status" do
      expect(build(:upload_batch, status: "done")).not_to be_valid
    end
  end

  describe "#refresh_status!" do
    it "marks the batch completed when all files are done" do
      batch = create(:upload_batch, total_files: 2, completed_files: 2, failed_files: 0)

      batch.refresh_status!
      expect(batch.status).to eq("completed")
    end

    it "marks the batch partial when there are failures and all files are accounted for" do
      batch = create(:upload_batch, total_files: 2, completed_files: 1, failed_files: 1)

      batch.refresh_status!
      expect(batch.status).to eq("partial")
    end
  end
end
