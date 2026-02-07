# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::SessionHistoryTool do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  before(:each) do
    Girb::SessionHistory.reset!
  end

  describe ".name" do
    it "returns get_session_history" do
      expect(described_class.name).to eq("get_session_history")
    end
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
    end
  end

  describe ".available?" do
    it "returns true when DEBUGGER__ is not defined" do
      expect(described_class.available?).to be true
    end

    context "when DEBUGGER__ is defined" do
      before { stub_const("DEBUGGER__", Module.new) }

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe ".parameters" do
    it "includes action as required" do
      params = described_class.parameters
      expect(params[:required]).to include("action")
    end

    it "includes all action options" do
      actions = described_class.parameters[:properties][:action][:enum]
      expected = %w[get_line get_range get_method list_methods full_history list_ai_conversations get_ai_detail]
      expect(actions).to eq(expected)
    end
  end

  describe "#execute" do
    describe "get_line action" do
      it "returns a specific line" do
        Girb::SessionHistory.record(5, "x = 1")
        result = tool.execute(test_binding, action: "get_line", line: 5)
        expect(result[:code]).to eq("x = 1")
        expect(result[:line]).to eq(5)
      end

      it "returns error when line not found" do
        result = tool.execute(test_binding, action: "get_line", line: 999)
        expect(result[:error]).to include("not found")
      end

      it "returns error when line parameter missing" do
        result = tool.execute(test_binding, action: "get_line")
        expect(result[:error]).to include("required")
      end
    end

    describe "get_range action" do
      before do
        Girb::SessionHistory.record(1, "a = 1")
        Girb::SessionHistory.record(2, "b = 2")
        Girb::SessionHistory.record(3, "c = 3")
      end

      it "returns entries in range" do
        result = tool.execute(test_binding, action: "get_range", start_line: 1, end_line: 2)
        expect(result[:entries].size).to eq(2)
        expect(result[:entries][0][:code]).to eq("a = 1")
        expect(result[:entries][1][:code]).to eq("b = 2")
      end

      it "returns error when parameters missing" do
        result = tool.execute(test_binding, action: "get_range", start_line: 1)
        expect(result[:error]).to include("required")
      end

      it "returns error when no entries in range" do
        result = tool.execute(test_binding, action: "get_range", start_line: 100, end_line: 200)
        expect(result[:error]).to include("No entries")
      end
    end

    describe "get_method action" do
      before do
        Girb::SessionHistory.record(1, "def greet(name)")
        Girb::SessionHistory.record(2, '  "Hello, #{name}"')
        Girb::SessionHistory.record(3, "end")
      end

      it "returns method source" do
        result = tool.execute(test_binding, action: "get_method", method_name: "greet")
        expect(result[:method_name]).to eq("greet")
        expect(result[:source]).to include("def greet")
        expect(result[:start_line]).to eq(1)
        expect(result[:end_line]).to eq(3)
      end

      it "returns error for unknown method" do
        result = tool.execute(test_binding, action: "get_method", method_name: "unknown")
        expect(result[:error]).to include("not found")
      end

      it "returns error when method_name missing" do
        result = tool.execute(test_binding, action: "get_method")
        expect(result[:error]).to include("required")
      end
    end

    describe "list_methods action" do
      it "lists defined methods" do
        Girb::SessionHistory.record(1, "def foo")
        Girb::SessionHistory.record(2, "end")
        Girb::SessionHistory.record(3, "def bar")
        Girb::SessionHistory.record(4, "end")

        result = tool.execute(test_binding, action: "list_methods")
        expect(result[:count]).to eq(2)
        expect(result[:methods].map { |m| m[:name] }).to include("foo", "bar")
      end

      it "returns message when no methods" do
        result = tool.execute(test_binding, action: "list_methods")
        expect(result[:message]).to include("No methods")
      end
    end

    describe "full_history action" do
      it "returns all history with line numbers" do
        Girb::SessionHistory.record(1, "x = 1")
        Girb::SessionHistory.record(2, "y = 2")

        result = tool.execute(test_binding, action: "full_history")
        expect(result[:count]).to eq(2)
        expect(result[:history]).to be_an(Array)
      end

      it "returns message when no history" do
        result = tool.execute(test_binding, action: "full_history")
        expect(result[:message]).to include("No history")
      end
    end

    describe "list_ai_conversations action" do
      it "includes current session AI conversations" do
        Girb::SessionHistory.record(1, "What is this?", is_ai_question: true)
        Girb::SessionHistory.record_ai_response(1, "It is a variable")

        result = tool.execute(test_binding, action: "list_ai_conversations")
        expect(result[:count]).to be >= 1
      end

      it "returns message when no conversations" do
        result = tool.execute(test_binding, action: "list_ai_conversations")
        expect(result[:message]).to include("No AI conversations")
      end
    end

    describe "get_ai_detail action" do
      it "returns error when line missing" do
        result = tool.execute(test_binding, action: "get_ai_detail")
        expect(result[:error]).to include("required")
      end
    end

    describe "unknown action" do
      it "returns error" do
        result = tool.execute(test_binding, action: "unknown_action")
        expect(result[:error]).to include("Unknown action")
      end
    end
  end
end
