# frozen_string_literal: true

RSpec.describe Girb::ExceptionCapture do
  describe ".capture" do
    it "stores exception information" do
      error = StandardError.new("test error")
      error.set_backtrace(["line1", "line2"])

      described_class.capture(error)

      expect(described_class.last_exception).to include(
        class: "StandardError",
        message: "test error"
      )
      expect(described_class.last_exception[:backtrace]).to eq(["line1", "line2"])
      expect(described_class.last_exception[:time]).to be_a(Time)
    end

    it "limits backtrace to 10 lines" do
      error = StandardError.new("test")
      error.set_backtrace(Array.new(20) { |i| "line#{i}" })

      described_class.capture(error)
      binding.girb
      expect(described_class.last_exception[:backtrace].length).to eq(10)
    end
  end

  describe ".clear" do
    it "clears stored exception" do
      described_class.capture(StandardError.new("test"))
      described_class.clear

      expect(described_class.last_exception).to be_nil
    end
  end

  describe ".install" do
    it "can be installed without error" do
      expect { described_class.install }.not_to raise_error
    end
  end

  describe ".uninstall" do
    it "can be uninstalled without error" do
      described_class.install
      expect { described_class.uninstall }.not_to raise_error
    end
  end
end
