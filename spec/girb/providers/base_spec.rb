# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Providers::Base do
  describe "#chat" do
    it "raises NotImplementedError" do
      provider = described_class.new
      expect {
        provider.chat(messages: [], system_prompt: "", tools: [])
      }.to raise_error(NotImplementedError, /must be implemented/)
    end

    it "includes class name in error message" do
      provider = described_class.new
      expect {
        provider.chat(messages: [], system_prompt: "", tools: [])
      }.to raise_error(NotImplementedError, /Girb::Providers::Base/)
    end
  end

  describe Girb::Providers::Base::Response do
    describe "#initialize" do
      it "initializes with defaults" do
        response = described_class.new
        expect(response.text).to be_nil
        expect(response.function_calls).to eq([])
        expect(response.error).to be_nil
        expect(response.raw_response).to be_nil
      end

      it "accepts text parameter" do
        response = described_class.new(text: "Hello")
        expect(response.text).to eq("Hello")
      end

      it "accepts function_calls parameter" do
        calls = [{ name: "evaluate_code", args: { code: "1+1" } }]
        response = described_class.new(function_calls: calls)
        expect(response.function_calls).to eq(calls)
      end

      it "accepts error parameter" do
        response = described_class.new(error: "API error")
        expect(response.error).to eq("API error")
      end

      it "accepts raw_response parameter" do
        raw = { status: 200 }
        response = described_class.new(raw_response: raw)
        expect(response.raw_response).to eq(raw)
      end
    end

    describe "#function_call?" do
      it "returns false when no function calls" do
        response = described_class.new
        expect(response.function_call?).to be false
      end

      it "returns false when function_calls is empty" do
        response = described_class.new(function_calls: [])
        expect(response.function_call?).to be false
      end

      it "returns true when function calls are present" do
        response = described_class.new(function_calls: [{ name: "test" }])
        expect(response.function_call?).to be true
      end
    end

    describe "combined attributes" do
      it "can have both text and function_calls" do
        response = described_class.new(text: "Calling tool", function_calls: [{ name: "test" }])
        expect(response.text).to eq("Calling tool")
        expect(response.function_call?).to be true
      end

      it "can have error with text" do
        response = described_class.new(text: "partial", error: "timeout")
        expect(response.text).to eq("partial")
        expect(response.error).to eq("timeout")
      end
    end
  end
end
