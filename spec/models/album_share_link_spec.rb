require "rails_helper"

RSpec.describe AlbumShareLink, type: :model do
  it "is valid for a studio curated album owner" do
    expect(build(:album_share_link, album: create(:album))).to be_valid
  end

  it "is valid for a user created album owner" do
    expect(build(:album_share_link, album: create(:album, :user_created))).to be_valid
  end

  it "stores a token digest instead of the raw token" do
    expect(described_class.digest_token("secret")).not_to eq("secret")
  end

  it "is inactive when revoked" do
    expect(build(:album_share_link, revoked_at: Time.current)).not_to be_active
  end
end
