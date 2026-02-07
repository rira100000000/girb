# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::ContinueAnalysis do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("re-invoked")
    end
  end

  describe ".parameters" do
    it "includes reason as required" do
      params = described_class.parameters
      expect(params[:properties]).to have_key(:reason)
      expect(params[:required]).to include("reason")
    end
  end

  describe ".available?" do
    it "returns true when DEBUGGER__ is not defined" do
      expect(described_class.available?).to be true
    end

    context "when DEBUGGER__ is defined" do
      before do
        stub_const("DEBUGGER__", Module.new)
      end

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe "#execute" do
    it "calls AutoContinue.request!" do
      tool.execute(test_binding, reason: "checking state")
      expect(Girb::AutoContinue.active?).to be true
    end

    it "returns success response" do
      result = tool.execute(test_binding, reason: "need context refresh")
      expect(result[:success]).to be true
      expect(result[:reason]).to eq("need context refresh")
    end

    it "includes informative message" do
      result = tool.execute(test_binding, reason: "test")
      expect(result[:message]).to include("re-invoked")
    end
  end
end
