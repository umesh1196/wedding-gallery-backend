require "rails_helper"

RSpec.describe Comment, type: :model do
  it "is valid with a photo, gallery session, and body" do
    expect(build(:comment)).to be_valid
  end

  it "requires the gallery session wedding to match the photo wedding" do
    comment = build(:comment)
    comment.gallery_session = create(:gallery_session)

    expect(comment).not_to be_valid
    expect(comment.errors[:gallery_session]).to include("must belong to the same wedding as the photo")
  end

  it "limits body length to 500 characters" do
    comment = build(:comment, body: "a" * 501)

    expect(comment).not_to be_valid
    expect(comment.errors[:body]).to include("is too long (maximum is 500 characters)")
  end

  it "rejects whitespace-only comments" do
    comment = build(:comment, body: "   \n\t  ")

    expect(comment).not_to be_valid
    expect(comment.errors[:body]).to include("can't be blank")
  end

  it "snapshots the visitor name when blank" do
    session = create(:gallery_session, visitor_name: "Asha")
    comment = build(:comment, photo: create(:photo, wedding: session.wedding, ceremony: create(:ceremony, wedding: session.wedding)), gallery_session: session, visitor_name_snapshot: nil)

    comment.validate

    expect(comment.visitor_name_snapshot).to eq("Asha")
  end
end
