require "rails_helper"

RSpec.describe DownloadRequest, type: :model do
  it "is valid for a full gallery request" do
    expect(build(:download_request)).to be_valid
  end

  it "requires a ceremony for ceremony-scoped requests" do
    request = build(:download_request, scope_type: "ceremony", ceremony: nil)

    expect(request).not_to be_valid
  end

  it "requires a shortlist for shortlist-scoped requests" do
    request = build(:download_request, scope_type: "shortlist", shortlist: nil)

    expect(request).not_to be_valid
  end

  it "requires scoped records to belong to the same wedding" do
    wedding = create(:wedding)
    other_wedding = create(:wedding)
    request = build(:download_request, wedding: wedding, ceremony: create(:ceremony, wedding: other_wedding), scope_type: "ceremony")

    expect(request).not_to be_valid
  end
end
