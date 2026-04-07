require "rails_helper"

RSpec.describe Studio, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      studio = build(:studio)
      expect(studio).to be_valid
    end

    it "requires an email" do
      studio = build(:studio, email: nil)
      expect(studio).not_to be_valid
    end

    it "rejects duplicate emails" do
      create(:studio, email: "test@example.com")
      studio = build(:studio, email: "test@example.com")
      expect(studio).not_to be_valid
    end

    it "rejects invalid email format" do
      studio = build(:studio, email: "not-an-email")
      expect(studio).not_to be_valid
    end

    it "requires studio_name" do
      studio = build(:studio, studio_name: nil)
      expect(studio).not_to be_valid
    end
  end

  describe "slug generation" do
    it "auto-generates slug from studio_name" do
      studio = create(:studio, studio_name: "Priya Photography")
      expect(studio.slug).to eq("priya-photography")
    end

    it "generates unique slugs when name clashes" do
      create(:studio, studio_name: "Priya Photography")
      studio2 = create(:studio, studio_name: "Priya Photography", email: "other@example.com")
      expect(studio2.slug).to eq("priya-photography-1")
    end
  end

  describe "#authenticate" do
    it "authenticates with correct password" do
      studio = create(:studio, password: "secret123")
      expect(studio.authenticate("secret123")).to eq(studio)
    end

    it "rejects wrong password" do
      studio = create(:studio, password: "secret123")
      expect(studio.authenticate("wrong")).to be_falsey
    end
  end
end
