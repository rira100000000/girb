# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::DebugSessionHistory do
  describe ".instance" do
    it "returns a DebugSessionHistory instance" do
      expect(described_class.instance).to be_a(described_class)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.instance).to equal(described_class.instance)
    end
  end

  describe ".reset!" do
    it "creates a new instance" do
      old = described_class.instance
      described_class.reset!
      expect(described_class.instance).not_to equal(old)
    end

    it "clears all entries" do
      described_class.record_command("next")
      described_class.reset!
      expect(described_class.entries).to be_empty
    end
  end

  describe ".record_command" do
    it "records a debugger command" do
      described_class.record_command("next")
      expect(described_class.entries.size).to eq(1)
      expect(described_class.entries.first.type).to eq(:command)
      expect(described_class.entries.first.content).to eq("next")
    end

    it "strips whitespace from command" do
      described_class.record_command("  step  ")
      expect(described_class.entries.first.content).to eq("step")
    end

    it "ignores nil commands" do
      described_class.record_command(nil)
      expect(described_class.entries).to be_empty
    end

    it "ignores blank commands" do
      described_class.record_command("   ")
      expect(described_class.entries).to be_empty
    end

    it "sets a timestamp" do
      described_class.record_command("next")
      expect(described_class.entries.first.timestamp).to be_a(Time)
    end
  end

  describe ".record_ai_question" do
    it "records an AI question" do
      described_class.record_ai_question("What is x?")
      expect(described_class.entries.size).to eq(1)
      expect(described_class.entries.first.type).to eq(:ai_question)
      expect(described_class.entries.first.content).to eq("What is x?")
    end

    it "has no response initially" do
      described_class.record_ai_question("What is x?")
      expect(described_class.entries.first.response).to be_nil
    end
  end

  describe ".record_ai_response" do
    it "attaches response to the pending AI question" do
      described_class.record_ai_question("What is x?")
      described_class.record_ai_response("x is 42")

      entry = described_class.entries.first
      expect(entry.response).to eq("x is 42")
    end

    it "does nothing when no pending AI question" do
      described_class.record_ai_response("orphan response")
      expect(described_class.entries).to be_empty
    end

    it "clears the pending entry after recording" do
      described_class.record_ai_question("Q1")
      described_class.record_ai_response("A1")
      described_class.record_ai_response("A2")

      expect(described_class.entries.first.response).to eq("A1")
    end
  end

  describe ".recent" do
    it "returns the last N entries" do
      5.times { |i| described_class.record_command("cmd#{i}") }
      recent = described_class.recent(3)
      expect(recent.size).to eq(3)
      expect(recent.map(&:content)).to eq(%w[cmd2 cmd3 cmd4])
    end

    it "defaults to 20 entries" do
      3.times { |i| described_class.record_command("cmd#{i}") }
      expect(described_class.recent.size).to eq(3)
    end

    it "returns all if fewer than count" do
      described_class.record_command("cmd1")
      expect(described_class.recent(10).size).to eq(1)
    end
  end

  describe ".ai_conversations" do
    it "returns only AI questions with responses" do
      described_class.record_command("next")
      described_class.record_ai_question("Q1")
      described_class.record_ai_response("A1")
      described_class.record_ai_question("Q2")  # pending, no response

      conversations = described_class.ai_conversations
      expect(conversations.size).to eq(1)
      expect(conversations.first.content).to eq("Q1")
      expect(conversations.first.response).to eq("A1")
    end

    it "returns empty array when no AI conversations" do
      described_class.record_command("next")
      expect(described_class.ai_conversations).to be_empty
    end
  end

  describe ".format_history" do
    it "formats commands with [cmd] prefix" do
      described_class.record_command("next")
      expect(described_class.format_history).to eq("[cmd] next")
    end

    it "formats AI Q&A with [ai] prefix" do
      described_class.record_ai_question("What is x?")
      described_class.record_ai_response("x is 42")

      result = described_class.format_history
      expect(result).to include("[ai] Q: What is x?")
      expect(result).to include("A: x is 42")
    end

    it "shows pending AI questions" do
      described_class.record_ai_question("What?")
      result = described_class.format_history
      expect(result).to include("pending...")
    end

    it "truncates long AI responses" do
      described_class.record_ai_question("Q")
      described_class.record_ai_response("x" * 200)

      result = described_class.format_history
      expect(result).to include("...")
    end

    it "respects count parameter" do
      5.times { |i| described_class.record_command("cmd#{i}") }
      result = described_class.format_history(2)
      expect(result.scan("[cmd]").size).to eq(2)
    end

    it "combines multiple entries" do
      described_class.record_command("step")
      described_class.record_ai_question("Why?")
      described_class.record_ai_response("Because")
      described_class.record_command("next")

      result = described_class.format_history
      lines = result.split("\n")
      expect(lines.first).to include("[cmd] step")
      expect(lines.last).to include("[cmd] next")
    end
  end

  describe "Entry struct" do
    it "has type, content, response, and timestamp" do
      entry = Girb::DebugSessionHistory::Entry.new(
        type: :command,
        content: "next",
        response: nil,
        timestamp: Time.now
      )
      expect(entry.type).to eq(:command)
      expect(entry.content).to eq("next")
    end
  end
end
