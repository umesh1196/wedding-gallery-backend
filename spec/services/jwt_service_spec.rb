require "rails_helper"

RSpec.describe JwtService do
  let(:payload) { { "studio_id" => "abc-123" } }

  describe ".encode" do
    it "returns a JWT string" do
      token = JwtService.encode(payload)
      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end
  end

  describe ".decode" do
    it "decodes a valid token" do
      token = JwtService.encode(payload)
      result = JwtService.decode(token)
      expect(result["studio_id"]).to eq("abc-123")
    end

    it "returns nil for an invalid token" do
      expect(JwtService.decode("not.a.token")).to be_nil
    end

    it "returns nil for an expired token" do
      token = JwtService.encode(payload, exp: 1.second.ago)
      expect(JwtService.decode(token)).to be_nil
    end
  end
end
