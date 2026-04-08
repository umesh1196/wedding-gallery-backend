require "rails_helper"

RSpec.describe Gallery::VerifyRateLimiter do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:limiter) do
    described_class.new(
      studio_slug: "priya-studio",
      wedding_slug: "priya-arjun",
      ip: "127.0.0.1",
      cache: cache
    )
  end

  it "allows attempts until the configured threshold is reached" do
    described_class::MAX_ATTEMPTS.times do |index|
      expect(limiter.rate_limited?).to eq(false), "expected attempt #{index + 1} to still be allowed"
      limiter.increment_failures!
    end

    expect(limiter.rate_limited?).to eq(true)
  end

  it "resets the failure count" do
    3.times { limiter.increment_failures! }

    limiter.reset!

    expect(limiter.rate_limited?).to eq(false)
  end
end
