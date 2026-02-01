# frozen_string_literal: true

RSpec.describe Girb::ContextBuilder do
  describe "#build" do
    let(:test_binding) do
      x = 1
      y = "hello"
      binding
    end

    subject { described_class.new(test_binding).build }

    it "captures local variables" do
      expect(subject[:local_variables]).to include(
        x: "1",
        y: '"hello"'
      )
    end

    it "captures self info" do
      expect(subject[:self_info]).to include(:class, :inspect)
      expect(subject[:self_info][:class]).to eq("RSpec::ExampleGroups::GirbContextBuilder::Build")
    end

    it "includes last_exception from ExceptionCapture" do
      Girb::ExceptionCapture.capture(StandardError.new("test"))

      result = described_class.new(test_binding).build

      expect(result[:last_exception]).to include(
        class: "StandardError",
        message: "test"
      )
    end

    it "handles nil last_value without irb_context" do
      expect(subject[:last_value]).to be_nil
    end

    it "includes session_history array" do
      expect(subject[:session_history]).to be_an(Array)
    end

    it "includes method_definitions array" do
      expect(subject[:method_definitions]).to be_an(Array)
    end
  end

  describe "safe_inspect" do
    it "truncates long strings" do
      builder = described_class.new(binding)
      long_string = "a" * 1000

      result = builder.send(:safe_inspect, long_string)

      expect(result.length).to be <= 503 # 500 + "..."
    end

    it "handles objects that fail to inspect" do
      builder = described_class.new(binding)
      bad_object = Object.new
      allow(bad_object).to receive(:inspect).and_raise("boom")

      result = builder.send(:safe_inspect, bad_object)

      expect(result).to include("inspect failed")
    end
  end
end
