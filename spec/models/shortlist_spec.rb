require "rails_helper"

RSpec.describe Shortlist, type: :model do
  it "allows one shortlist per wedding and gallery session" do
    wedding = create(:wedding)
    session = create(:gallery_session, wedding: wedding)
    create(:shortlist, wedding: wedding, gallery_session: session)

    duplicate = build(:shortlist, wedding: wedding, gallery_session: session)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:gallery_session_id]).to include("has already been taken")
  end
end
