# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::DebugSessionHistoryTool do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

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
    it "returns falsey when DEBUGGER__ is not defined" do
      expect(described_class.available?).to be_falsey
    end

    context "when DEBUGGER__ is defined" do
      before { stub_const("DEBUGGER__", Module.new) }

      it "returns truthy" do
        expect(described_class.available?).to be_truthy
      end
    end
  end

  describe ".parameters" do
    it "includes action as required" do
      expect(described_class.parameters[:required]).to include("action")
    end

    it "includes action enum with full_history and list_ai_conversations" do
      actions = described_class.parameters[:properties][:action][:enum]
      expect(actions).to eq(%w[full_history list_ai_conversations])
    end
  end

  describe "#execute" do
    describe "full_history action" do
      it "returns current session debug history" do
        Girb::DebugSessionHistory.record_command("next")
        Girb::DebugSessionHistory.record_command("step")

        result = tool.execute(test_binding, action: "full_history")
        expect(result[:current_session_history]).to include("[cmd] next")
        expect(result[:current_session_history]).to include("[cmd] step")
      end

      it "returns message when no history" do
        result = tool.execute(test_binding, action: "full_history")
        expect(result[:message]).to eq("No history available")
      end

      it "respects count parameter" do
        5.times { |i| Girb::DebugSessionHistory.record_command("cmd#{i}") }
        result = tool.execute(test_binding, action: "full_history", count: 2)
        history = result[:current_session_history]
        expect(history.scan("[cmd]").size).to eq(2)
      end
    end

    describe "list_ai_conversations action" do
      it "returns AI conversations from debug session" do
        Girb::DebugSessionHistory.record_ai_question("What is x?")
        Girb::DebugSessionHistory.record_ai_response("x is 42")

        result = tool.execute(test_binding, action: "list_ai_conversations")
        expect(result[:conversations]).to be_an(Array)
        expect(result[:conversations].first[:question]).to eq("What is x?")
      end

      it "returns message when no conversations" do
        result = tool.execute(test_binding, action: "list_ai_conversations")
        expect(result[:message]).to include("No AI conversations")
      end
    end

    describe "unknown action" do
      it "returns error" do
        result = tool.execute(test_binding, action: "invalid")
        expect(result[:error]).to include("Unknown action")
      end
    end
  end
end
