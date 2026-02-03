# frozen_string_literal: true

RSpec.describe Girb::Configuration do
  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.provider).to be_nil
      expect(config.debug).to be false
      expect(config.custom_prompt).to be_nil
    end

    it "reads GIRB_DEBUG from environment" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GIRB_DEBUG").and_return("1")
      config = described_class.new

      expect(config.debug).to be true
    end
  end

  describe "accessors" do
    it "allows setting configuration values" do
      config = described_class.new
      config.debug = true
      config.custom_prompt = "Test prompt"

      expect(config.debug).to be true
      expect(config.custom_prompt).to eq("Test prompt")
    end
  end

  describe "#provider!" do
    it "returns provider if set" do
      config = described_class.new
      mock_provider = double("provider")
      config.provider = mock_provider

      expect(config.provider!).to eq(mock_provider)
    end

    it "raises ConfigurationError if provider is not set" do
      config = described_class.new

      expect { config.provider! }.to raise_error(Girb::ConfigurationError)
    end
  end
end

RSpec.describe Girb do
  describe ".configure" do
    it "yields configuration block" do
      Girb.configure do |config|
        config.debug = true
        config.custom_prompt = "Test"
      end

      expect(Girb.configuration.debug).to be true
      expect(Girb.configuration.custom_prompt).to eq("Test")
    end

    it "returns configuration" do
      result = Girb.configure

      expect(result).to be_a(Girb::Configuration)
    end
  end
end
