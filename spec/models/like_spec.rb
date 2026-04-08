require "rails_helper"

RSpec.describe Like, type: :model do
  it "is valid when the liked photo belongs to the session wedding" do
    wedding = create(:wedding)
    session = create(:gallery_session, wedding: wedding)
    photo = create(:photo, wedding: wedding, ceremony: create(:ceremony, wedding: wedding))

    like = described_class.new(photo: photo, gallery_session: session)

    expect(like).to be_valid
  end

  it "is invalid when the photo belongs to another wedding" do
    session_wedding = create(:wedding)
    other_wedding = create(:wedding)
    session = create(:gallery_session, wedding: session_wedding)
    photo = create(:photo, wedding: other_wedding, ceremony: create(:ceremony, wedding: other_wedding))

    like = described_class.new(photo: photo, gallery_session: session)

    expect(like).not_to be_valid
    expect(like.errors[:photo]).to include("must belong to the session wedding")
  end
end
