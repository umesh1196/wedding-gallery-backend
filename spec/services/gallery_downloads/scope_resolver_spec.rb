require "rails_helper"

RSpec.describe GalleryDownloads::ScopeResolver do
  let(:wedding) { create(:wedding) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding) }
  let(:first_ceremony) { create(:ceremony, wedding: wedding, slug: "haldi") }
  let(:second_ceremony) { create(:ceremony, wedding: wedding, slug: "reception") }
  let!(:first_photo) { create(:photo, wedding: wedding, ceremony: first_ceremony, original_filename: "first.jpg") }
  let!(:second_photo) { create(:photo, wedding: wedding, ceremony: second_ceremony, original_filename: "second.jpg") }

  it "resolves ceremony-scoped downloads" do
    result = described_class.new(
      wedding: wedding,
      gallery_session: gallery_session,
      scope_type: "ceremony",
      ceremony_slug: first_ceremony.slug
    ).call

    expect(result[:photos].map(&:id)).to eq([ first_photo.id ])
    expect(result[:filename]).to include(first_ceremony.slug)
  end

  it "resolves shortlist-scoped downloads" do
    shortlist = create(:shortlist, wedding: wedding, gallery_session: gallery_session)
    create(:shortlist_photo, shortlist: shortlist, photo: second_photo)

    result = described_class.new(
      wedding: wedding,
      gallery_session: gallery_session,
      scope_type: "shortlist"
    ).call

    expect(result[:photos].map(&:id)).to eq([ second_photo.id ])
    expect(result[:shortlist]).to eq(shortlist)
  end

  it "resolves full gallery downloads" do
    result = described_class.new(
      wedding: wedding,
      gallery_session: gallery_session,
      scope_type: "full_gallery"
    ).call

    expect(result[:photos].map(&:id)).to eq([ first_photo.id, second_photo.id ])
  end
end
