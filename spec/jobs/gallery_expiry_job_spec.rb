require "rails_helper"

RSpec.describe GalleryExpiryJob, type: :job do
  describe "#perform" do
    it "deactivates expired active weddings and revokes their gallery sessions" do
      expired_wedding = create(:wedding, expires_at: 1.day.ago, is_active: true)
      session = create(:gallery_session, wedding: expired_wedding, revoked_at: nil)
      still_active = create(:wedding, expires_at: 5.days.from_now, is_active: true)

      described_class.perform_now

      expect(expired_wedding.reload.is_active).to be(false)
      expect(session.reload.revoked_at).to be_present
      expect(still_active.reload.is_active).to be(true)
    end

    it "is idempotent for weddings already inactive" do
      wedding = create(:wedding, expires_at: 3.days.ago, is_active: false)

      expect { described_class.perform_now }.not_to change { wedding.reload.updated_at }
    end
  end
end
