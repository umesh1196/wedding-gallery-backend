require "rails_helper"

RSpec.describe ShareLink, type: :model do
  it "is valid with default attributes" do
    expect(build(:share_link)).to be_valid
  end

  it "stores a token digest and not the raw token" do
    expect(described_class.digest_token("abc123")).not_to eq("abc123")
  end

  it "is inactive when revoked" do
    expect(build(:share_link, revoked_at: Time.current)).not_to be_active
  end

  it "is inactive when expired" do
    expect(build(:share_link, expires_at: 1.day.ago)).not_to be_active
  end
end
