# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::AutoContinue do
  describe "MAX_ITERATIONS" do
    it "is defined as 20" do
      expect(described_class::MAX_ITERATIONS).to eq(20)
    end
  end

  describe ".active?" do
    it "returns false by default" do
      expect(described_class.active?).to be false
    end

    it "returns true after request!" do
      described_class.request!
      expect(described_class.active?).to be true
    end
  end

  describe ".request!" do
    it "sets active to true" do
      described_class.request!
      expect(described_class.active?).to be true
    end
  end

  describe ".reset!" do
    it "sets active to false" do
      described_class.request!
      described_class.reset!
      expect(described_class.active?).to be false
    end
  end

  describe ".interrupted?" do
    it "returns false by default" do
      expect(described_class.interrupted?).to be false
    end

    it "returns true after interrupt!" do
      described_class.interrupt!
      expect(described_class.interrupted?).to be true
    end
  end

  describe ".interrupt!" do
    it "sets interrupted to true" do
      described_class.interrupt!
      expect(described_class.interrupted?).to be true
    end
  end

  describe ".clear_interrupt!" do
    it "sets interrupted to false" do
      described_class.interrupt!
      described_class.clear_interrupt!
      expect(described_class.interrupted?).to be false
    end
  end

  describe "state independence" do
    it "active and interrupted states are independent" do
      described_class.request!
      described_class.interrupt!
      expect(described_class.active?).to be true
      expect(described_class.interrupted?).to be true

      described_class.reset!
      expect(described_class.active?).to be false
      expect(described_class.interrupted?).to be true
    end
  end
end
