# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::ConversationHistory do
  describe ".instance" do
    it "returns a ConversationHistory instance" do
      expect(described_class.instance).to be_a(described_class)
    end

    it "returns the same instance on repeated calls" do
      expect(described_class.instance).to equal(described_class.instance)
    end
  end

  describe ".reset!" do
    it "creates a new instance" do
      old_instance = described_class.instance
      described_class.reset!
      expect(described_class.instance).not_to equal(old_instance)
    end

    it "clears all messages" do
      described_class.add_user_message("hello")
      described_class.reset!
      expect(described_class.messages).to be_empty
    end
  end

  describe ".add_user_message" do
    it "adds a user message" do
      described_class.add_user_message("test question")
      expect(described_class.messages.size).to eq(1)
      expect(described_class.messages.first.role).to eq("user")
      expect(described_class.messages.first.content).to eq("test question")
    end

    it "adds multiple user messages" do
      described_class.add_user_message("first")
      described_class.add_user_message("second")
      expect(described_class.messages.size).to eq(2)
    end
  end

  describe ".add_assistant_message" do
    it "adds a model message" do
      described_class.add_assistant_message("response text")
      expect(described_class.messages.size).to eq(1)
      expect(described_class.messages.first.role).to eq("model")
      expect(described_class.messages.first.content).to eq("response text")
    end

    it "includes pending tool calls when present" do
      described_class.add_tool_call("evaluate_code", { code: "1+1" }, { result: "2" }, id: "call_1")
      described_class.add_assistant_message("The result is 2")

      msg = described_class.messages.first
      expect(msg.role).to eq("model")
      expect(msg.tool_calls).to be_an(Array)
      expect(msg.tool_calls.size).to eq(1)
      expect(msg.tool_calls.first[:name]).to eq("evaluate_code")
    end

    it "clears pending tool calls after adding them to a message" do
      described_class.add_tool_call("evaluate_code", { code: "1+1" }, { result: "2" }, id: "call_1")
      described_class.add_assistant_message("result")
      described_class.add_assistant_message("another response")

      expect(described_class.messages.last.tool_calls).to be_nil
    end
  end

  describe ".add_tool_call" do
    it "accumulates tool calls as pending" do
      described_class.add_tool_call("read_file", { path: "test.rb" }, { content: "code" }, id: "call_1")
      described_class.add_tool_call("evaluate_code", { code: "1+1" }, { result: "2" }, id: "call_2")
      described_class.add_assistant_message("done")

      msg = described_class.messages.first
      expect(msg.tool_calls.size).to eq(2)
      expect(msg.tool_calls[0][:name]).to eq("read_file")
      expect(msg.tool_calls[1][:name]).to eq("evaluate_code")
    end

    it "generates an id when not provided" do
      described_class.add_tool_call("read_file", { path: "test.rb" }, { content: "code" })
      described_class.add_assistant_message("done")

      msg = described_class.messages.first
      expect(msg.tool_calls.first[:id]).to start_with("call_")
    end
  end

  describe ".clear!" do
    it "clears all messages" do
      described_class.add_user_message("hello")
      described_class.add_assistant_message("hi")
      described_class.clear!
      expect(described_class.messages).to be_empty
    end

    it "clears pending tool calls" do
      described_class.add_tool_call("read_file", {}, {}, id: "call_1")
      described_class.clear!
      described_class.add_assistant_message("response")
      expect(described_class.messages.first.tool_calls).to be_nil
    end
  end

  describe ".to_contents" do
    it "returns Gemini API format" do
      described_class.add_user_message("hello")
      described_class.add_assistant_message("hi")

      contents = described_class.to_contents
      expect(contents.size).to eq(2)
      expect(contents[0]).to eq({ role: "user", parts: [{ text: "hello" }] })
      expect(contents[1]).to eq({ role: "model", parts: [{ text: "hi" }] })
    end

    it "returns empty array when no messages" do
      expect(described_class.to_contents).to eq([])
    end
  end

  describe ".to_normalized" do
    it "converts user messages with :user role" do
      described_class.add_user_message("question")
      result = described_class.to_normalized
      expect(result.first[:role]).to eq(:user)
      expect(result.first[:content]).to eq("question")
    end

    it "converts model messages to :assistant role" do
      described_class.add_assistant_message("answer")
      result = described_class.to_normalized
      expect(result.first[:role]).to eq(:assistant)
    end

    it "includes tool calls and results" do
      described_class.add_tool_call("evaluate_code", { code: "1" }, { result: "1" }, id: "tc1")
      described_class.add_assistant_message("done")

      result = described_class.to_normalized
      # assistant message + tool_call + tool_result
      tool_call = result.find { |r| r[:role] == :tool_call }
      tool_result = result.find { |r| r[:role] == :tool_result }

      expect(tool_call[:name]).to eq("evaluate_code")
      expect(tool_call[:id]).to eq("tc1")
      expect(tool_result[:name]).to eq("evaluate_code")
      expect(tool_result[:result]).to eq({ result: "1" })
    end

    it "includes pending tool calls not yet assigned to a message" do
      described_class.add_tool_call("read_file", { path: "a.rb" }, { content: "x" }, id: "tc2")

      result = described_class.to_normalized
      expect(result.any? { |r| r[:role] == :tool_call && r[:id] == "tc2" }).to be true
    end
  end

  describe ".summary" do
    it "returns summary of conversation" do
      described_class.add_user_message("What is this?")
      described_class.add_assistant_message("This is a variable.")

      summary = described_class.summary
      expect(summary.size).to eq(2)
      expect(summary[0]).to start_with("USER: ")
      expect(summary[1]).to start_with("AI: ")
    end

    it "truncates long content" do
      described_class.add_user_message("x" * 100)
      summary = described_class.summary
      expect(summary.first).to include("...")
      expect(summary.first.length).to be < 100
    end

    it "returns empty array when no messages" do
      expect(described_class.summary).to eq([])
    end
  end

  describe "Message struct" do
    it "has role, content, tool_calls, and tool_results attributes" do
      msg = Girb::ConversationHistory::Message.new(
        role: "user",
        content: "hello",
        tool_calls: [],
        tool_results: nil
      )
      expect(msg.role).to eq("user")
      expect(msg.content).to eq("hello")
      expect(msg.tool_calls).to eq([])
      expect(msg.tool_results).to be_nil
    end
  end
end
