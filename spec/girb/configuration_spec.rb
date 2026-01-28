# frozen_string_literal: true

RSpec.describe Girb::Configuration do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.model).to eq("gemini-2.5-flash")
      expect(config.debug).to be false
    end

    it "reads GEMINI_API_KEY from environment" do
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return("test-key")
      config = described_class.new

      expect(config.gemini_api_key).to eq("test-key")
    end
  end

  describe "accessors" do
    it "allows setting configuration values" do
      config = described_class.new
      config.gemini_api_key = "new-key"
      config.model = "gemini-pro"
      config.debug = true

      expect(config.gemini_api_key).to eq("new-key")
      expect(config.model).to eq("gemini-pro")
      expect(config.debug).to be true
    end
  end
end

RSpec.describe Girb do
  describe ".configure" do
    it "yields configuration block" do
      Girb.configure do |config|
        config.gemini_api_key = "block-key"
        config.debug = true
      end

      expect(Girb.configuration.gemini_api_key).to eq("block-key")
      expect(Girb.configuration.debug).to be true
    end

    it "returns configuration" do
      result = Girb.configure

      expect(result).to be_a(Girb::Configuration)
    end
  end
end
