# frozen_string_literal: true

RSpec.describe Girb::Tools do
  describe ".available_tools" do
    it "returns core tools" do
      tools = described_class.available_tools

      expect(tools).to include(Girb::Tools::InspectObject)
      expect(tools).to include(Girb::Tools::GetSource)
      expect(tools).to include(Girb::Tools::ListMethods)
    end
  end

  describe ".find_tool" do
    it "finds tool by name" do
      tool = described_class.find_tool("inspect_object")

      expect(tool).to eq(Girb::Tools::InspectObject)
    end

    it "returns nil for unknown tool" do
      tool = described_class.find_tool("unknown")

      expect(tool).to be_nil
    end
  end

  describe ".to_gemini_tools" do
    it "returns tool declarations for Gemini API" do
      tools = described_class.to_gemini_tools

      expect(tools).to be_an(Array)
      expect(tools.first).to include(:name, :description, :parameters)
    end
  end
end

RSpec.describe Girb::Tools::InspectObject do
  describe ".tool_name" do
    it "returns snake_case name" do
      expect(described_class.tool_name).to eq("inspect_object")
    end
  end

  describe "#execute" do
    let(:test_binding) do
      user = { name: "Alice", age: 30 }
      binding
    end

    it "inspects a variable" do
      tool = described_class.new
      result = tool.execute(test_binding, expression: "user")

      expect(result[:class]).to eq("Hash")
      expect(result[:value]).to include("Alice")
    end

    it "returns error for invalid expression" do
      tool = described_class.new
      result = tool.execute(test_binding, expression: "undefined_var")

      expect(result[:error]).to include("NameError")
    end

    it "returns error for syntax errors" do
      tool = described_class.new
      result = tool.execute(test_binding, expression: "def def")

      expect(result[:error]).to include("Syntax error")
    end
  end
end

RSpec.describe Girb::Tools::GetSource do
  describe "#execute" do
    it "gets class info for a class name" do
      tool = described_class.new
      result = tool.execute(binding, target: "String")

      expect(result[:name]).to eq("String")
      expect(result[:ancestors]).to include("Object")
      expect(result[:instance_methods]).to be_an(Array)
    end

    it "returns error for non-existent class" do
      tool = described_class.new
      result = tool.execute(binding, target: "NonExistentClass")

      expect(result[:error]).to include("Not found")
    end
  end
end

RSpec.describe Girb::Tools::ListMethods do
  describe "#execute" do
    it "lists methods on an object" do
      tool = described_class.new
      result = tool.execute(binding, expression: '"hello"')

      expect(result[:methods]).to be_an(Array)
    end

    it "filters methods by pattern" do
      tool = described_class.new
      result = tool.execute(binding, expression: '"hello"', pattern: "up")

      expect(result[:methods]).to include(:upcase)
      expect(result[:methods]).not_to include(:downcase)
    end

    it "returns error for invalid pattern" do
      tool = described_class.new
      result = tool.execute(binding, expression: '"hello"', pattern: "[invalid")

      expect(result[:error]).to include("Invalid pattern")
    end
  end
end
