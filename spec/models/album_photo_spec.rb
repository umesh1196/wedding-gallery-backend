require "rails_helper"

RSpec.describe AlbumPhoto, type: :model do
  it "is valid when the photo belongs to the album ceremony" do
    expect(build(:album_photo)).to be_valid
  end

  it "prevents duplicate photo membership in the same album" do
    album_photo = create(:album_photo)
    duplicate = build(:album_photo, album: album_photo.album, photo: album_photo.photo)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:photo_id]).to include("has already been taken")
  end

  it "requires the photo to belong to the same ceremony as the album" do
    album = create(:album)
    other_wedding = create(:wedding)
    other_photo = create(:photo, wedding: other_wedding, ceremony: create(:ceremony, wedding: other_wedding))
    album_photo = build(:album_photo, album: album, photo: other_photo)

    expect(album_photo).not_to be_valid
    expect(album_photo.errors[:photo]).to include("must belong to the album ceremony")
  end

  it "updates the album photos_count" do
    album = create(:album)

    create(:album_photo, album: album)
    expect(album.reload.photos_count).to eq(1)

    album.album_photos.first.destroy!
    expect(album.reload.photos_count).to eq(0)
  end
end
