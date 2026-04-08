require "rails_helper"

RSpec.describe Gallery::CommentRateLimiter do
  let(:wedding) { create(:wedding) }
  let(:gallery_session) { create(:gallery_session, wedding: wedding) }
  let(:limiter) { described_class.new(wedding: wedding, gallery_session: gallery_session, ip: "127.0.0.1") }

  before do
    Rails.cache.clear
    described_class::FALLBACK_CACHE.clear
  end

  it "allows up to the configured number of comments" do
    5.times do
      expect(limiter.allowed?).to eq(true)
      limiter.record!
    end

    expect(limiter.allowed?).to eq(false)
  end
end
