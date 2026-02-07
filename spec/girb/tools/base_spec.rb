# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::Base do
  describe ".tool_name" do
    it "converts class name to snake_case" do
      expect(described_class.tool_name).to eq("base")
    end

    it "converts multi-word class names" do
      stub_const("Girb::Tools::EvaluateCode", Class.new(described_class))
      expect(Girb::Tools::EvaluateCode.tool_name).to eq("evaluate_code")
    end

    it "converts single-word class names" do
      stub_const("Girb::Tools::Find", Class.new(described_class))
      expect(Girb::Tools::Find.tool_name).to eq("find")
    end
  end

  describe ".description" do
    it "raises NotImplementedError" do
      expect { described_class.description }.to raise_error(NotImplementedError)
    end
  end

  describe ".parameters" do
    it "raises NotImplementedError" do
      expect { described_class.parameters }.to raise_error(NotImplementedError)
    end
  end

  describe ".to_gemini_tool" do
    it "returns a hash with name, description, and parameters" do
      tool_class = Class.new(described_class) do
        def self.name
          "Girb::Tools::TestTool"
        end

        def self.description
          "A test tool"
        end

        def self.parameters
          { type: "object", properties: {} }
        end
      end
      stub_const("Girb::Tools::TestTool", tool_class)

      result = Girb::Tools::TestTool.to_gemini_tool
      expect(result[:name]).to eq("test_tool")
      expect(result[:description]).to eq("A test tool")
      expect(result[:parameters]).to eq({ type: "object", properties: {} })
    end
  end

  describe ".available?" do
    it "returns true by default" do
      expect(described_class.available?).to be true
    end
  end

  describe "#execute" do
    it "raises NotImplementedError" do
      tool = described_class.new
      expect { tool.execute(binding) }.to raise_error(NotImplementedError)
    end
  end

  describe "#safe_inspect" do
    let(:tool) { described_class.new }

    it "returns inspect string for simple objects" do
      result = tool.send(:safe_inspect, 42)
      expect(result).to eq("42")
    end

    it "truncates long inspect output" do
      long_str = "x" * 2000
      result = tool.send(:safe_inspect, long_str)
      expect(result.length).to be <= 1010  # 1000 + "..." + quotes
    end

    it "handles objects with failing inspect" do
      bad_obj = Object.new
      def bad_obj.inspect
        raise "broken"
      end

      result = tool.send(:safe_inspect, bad_obj)
      expect(result).to include("inspect failed")
    end
  end
end
