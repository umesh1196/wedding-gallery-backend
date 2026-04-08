require "rails_helper"

RSpec.describe GallerySession, type: :model do
  describe ".issue_for!" do
    it "returns a raw token and stores only its digest" do
      wedding = create(:wedding)

      session = nil
      raw_token = nil

      expect {
        session, raw_token = described_class.issue_for!(wedding: wedding, visitor_name: "Aditi")
      }.to change(described_class, :count).by(1)

      expect(raw_token).to be_present
      expect(session.session_token_digest).to eq(described_class.digest_token(raw_token))
      expect(session.session_token_digest).not_to eq(raw_token)
      expect(session.visitor_name).to eq("Aditi")
    end
  end

  describe "#expired?" do
    it "returns true when the session has been inactive for more than 24 hours" do
      session = create(:gallery_session, last_active_at: 25.hours.ago)

      expect(session).to be_expired
    end

    it "returns false when the session is still active" do
      session = create(:gallery_session, last_active_at: 2.hours.ago)

      expect(session).not_to be_expired
    end
  end

  describe "#active?" do
    it "returns false for a revoked session" do
      session = create(:gallery_session, revoked_at: Time.current)

      expect(session).not_to be_active
    end
  end
end
