require "rails_helper"

RSpec.describe Album, type: :model do
  it "is valid for a studio curated album with a studio creator" do
    expect(build(:album)).to be_valid
  end

  it "is valid for a user created album with a gallery session creator" do
    expect(build(:album, :user_created)).to be_valid
  end

  it "requires the creator to match the album type" do
    album = build(:album, album_type: "studio_curated", created_by_studio: nil, created_by_gallery_session: create(:gallery_session))

    expect(album).not_to be_valid
    expect(album.errors[:album_type]).to include("must match the creator type")
  end

  it "requires exactly one creator path" do
    ceremony = create(:ceremony)
    album = build(
      :album,
      ceremony: ceremony,
      created_by_studio: ceremony.wedding.studio,
      created_by_gallery_session: create(:gallery_session, wedding: ceremony.wedding)
    )

    expect(album).not_to be_valid
    expect(album.errors[:base]).to include("must have exactly one owner")
  end

  it "validates the cover photo belongs to the same ceremony" do
    album = build(:album)
    other_wedding = create(:wedding)
    other_photo = create(:photo, wedding: other_wedding, ceremony: create(:ceremony, wedding: other_wedding))
    album.cover_photo = other_photo

    expect(album).not_to be_valid
    expect(album.errors[:cover_photo]).to include("must belong to the same ceremony")
  end
end
