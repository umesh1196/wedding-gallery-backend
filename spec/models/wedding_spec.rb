require "rails_helper"

RSpec.describe Wedding, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:wedding)).to be_valid
    end

    it "requires a couple name" do
      expect(build(:wedding, couple_name: nil)).not_to be_valid
    end

    it "requires an expires_at timestamp" do
      expect(build(:wedding, expires_at: nil)).not_to be_valid
    end

    it "requires a password on create" do
      expect(build(:wedding, password: nil)).not_to be_valid
    end

    it "restricts allow_download to supported values" do
      expect(build(:wedding, allow_download: "sometimes")).not_to be_valid
    end
  end

  describe "slug generation" do
    it "auto-generates slug from couple_name" do
      wedding = create(:wedding, couple_name: "Priya & Arjun")
      expect(wedding.slug).to eq("priya-arjun")
    end

    it "generates unique slugs per studio" do
      studio = create(:studio)
      create(:wedding, studio: studio, couple_name: "Priya & Arjun")

      wedding = create(:wedding, studio: studio, couple_name: "Priya & Arjun")
      expect(wedding.slug).to eq("priya-arjun-1")
    end

    it "allows the same slug in different studios" do
      create(:wedding, slug: "shared-slug")
      expect(build(:wedding, slug: "shared-slug")).to be_valid
    end
  end

  describe "password hashing" do
    it "stores a password hash and authenticates with the raw password" do
      wedding = create(:wedding, password: "secret123")

      expect(wedding.password_hash).to be_present
      expect(wedding.authenticate("secret123")).to be true
      expect(wedding.authenticate("wrong")).to be false
    end
  end

  describe "#expired?" do
    it "is true when expires_at is in the past" do
      expect(build(:wedding, expires_at: 1.day.ago)).to be_expired
    end

    it "is true when the wedding is inactive" do
      expect(build(:wedding, is_active: false)).to be_expired
    end

    it "is false for active future weddings" do
      expect(build(:wedding, expires_at: 1.day.from_now, is_active: true)).not_to be_expired
    end
  end
end
