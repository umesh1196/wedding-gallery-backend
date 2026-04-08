require "rails_helper"

RSpec.describe GalleryDownloads::Policy do
  let(:wedding) { create(:wedding, allow_download: allow_download) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding) }
  let(:ceremony) { create(:ceremony, wedding: wedding) }
  let(:photo) { create(:photo, wedding: wedding, ceremony: ceremony) }

  subject(:policy) { described_class.new(wedding: wedding, gallery_session: gallery_session) }

  context "when allow_download is all" do
    let(:allow_download) { "all" }

    it "allows any photo and bulk scope" do
      expect(policy.allow_single_photo?(photo)).to eq(true)
      expect(policy.allow_bulk_scope?("ceremony")).to eq(true)
      expect(policy.allow_bulk_scope?("shortlist")).to eq(true)
      expect(policy.allow_bulk_scope?("full_gallery")).to eq(true)
    end
  end

  context "when allow_download is shortlist" do
    let(:allow_download) { "shortlist" }

    it "allows only shortlisted photos and shortlist bulk downloads" do
      shortlist = create(:shortlist, wedding: wedding, gallery_session: gallery_session)
      create(:shortlist_photo, shortlist: shortlist, photo: photo)

      expect(policy.allow_single_photo?(photo)).to eq(true)
      expect(policy.allow_bulk_scope?("shortlist")).to eq(true)
      expect(policy.allow_bulk_scope?("ceremony")).to eq(false)
      expect(policy.allow_bulk_scope?("full_gallery")).to eq(false)
    end

    it "blocks photos not in the current session shortlist" do
      expect(policy.allow_single_photo?(photo)).to eq(false)
    end
  end

  context "when allow_download is none" do
    let(:allow_download) { "none" }

    it "blocks everything" do
      expect(policy.allow_single_photo?(photo)).to eq(false)
      expect(policy.allow_bulk_scope?("shortlist")).to eq(false)
    end
  end
end
