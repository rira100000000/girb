# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::GetCurrentDirectory do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("directory")
    end
  end

  describe ".parameters" do
    it "has no required parameters" do
      expect(described_class.parameters[:required]).to eq([])
    end
  end

  describe "#execute" do
    it "returns current_directory" do
      result = tool.execute(test_binding)
      expect(result[:current_directory]).to eq(Dir.pwd)
    end

    it "returns home_directory" do
      result = tool.execute(test_binding)
      expect(result[:home_directory]).to eq(Dir.home)
    end
  end
end
