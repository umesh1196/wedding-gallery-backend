require "rails_helper"

RSpec.describe Ceremony, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:ceremony)).to be_valid
    end

    it "requires a name" do
      expect(build(:ceremony, name: nil)).not_to be_valid
    end

    it "requires unique slug within a wedding" do
      wedding = create(:wedding)
      create(:ceremony, wedding: wedding, slug: "haldi-ceremony")

      duplicate = build(:ceremony, wedding: wedding, slug: "haldi-ceremony")
      expect(duplicate).not_to be_valid
    end

    it "allows the same slug in another wedding" do
      create(:ceremony, slug: "haldi-ceremony")
      expect(build(:ceremony, slug: "haldi-ceremony")).to be_valid
    end
  end

  describe "slug generation" do
    it "auto-generates slug from name" do
      ceremony = create(:ceremony, name: "Wedding Ceremony")
      expect(ceremony.slug).to eq("wedding-ceremony")
    end

    it "generates unique slugs within a wedding" do
      wedding = create(:wedding)
      create(:ceremony, wedding: wedding, name: "Reception")

      ceremony = create(:ceremony, wedding: wedding, name: "Reception")
      expect(ceremony.slug).to eq("reception-1")
    end
  end
end
