require "rails_helper"

RSpec.describe ShortlistPhoto, type: :model do
  it "is valid when the photo belongs to the shortlist wedding" do
    wedding = create(:wedding)
    shortlist = create(:shortlist, wedding: wedding, gallery_session: create(:gallery_session, wedding: wedding))
    photo = create(:photo, wedding: wedding, ceremony: create(:ceremony, wedding: wedding))

    record = described_class.new(shortlist: shortlist, photo: photo)

    expect(record).to be_valid
  end

  it "is invalid when the photo belongs to another wedding" do
    shortlist_wedding = create(:wedding)
    other_wedding = create(:wedding)
    shortlist = create(:shortlist, wedding: shortlist_wedding, gallery_session: create(:gallery_session, wedding: shortlist_wedding))
    photo = create(:photo, wedding: other_wedding, ceremony: create(:ceremony, wedding: other_wedding))

    record = described_class.new(shortlist: shortlist, photo: photo)

    expect(record).not_to be_valid
    expect(record.errors[:photo]).to include("must belong to the shortlist wedding")
  end
end
