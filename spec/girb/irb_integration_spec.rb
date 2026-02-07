# frozen_string_literal: true

require "spec_helper"

# Load IrbIntegration module for testing pure helper methods
# We don't call setup to avoid monkey-patching IRB
require "girb/irb_integration"

RSpec.describe Girb::IrbIntegration do
  describe ".debug_command?" do
    it "recognizes 'next' as a debug command" do
      expect(described_class.debug_command?("next")).to be true
    end

    it "recognizes 'n' as a debug command" do
      expect(described_class.debug_command?("n")).to be true
    end

    it "recognizes 'step' as a debug command" do
      expect(described_class.debug_command?("step")).to be true
    end

    it "recognizes 's' as a debug command" do
      expect(described_class.debug_command?("s")).to be true
    end

    it "recognizes 'continue' as a debug command" do
      expect(described_class.debug_command?("continue")).to be true
    end

    it "recognizes 'c' as a debug command" do
      expect(described_class.debug_command?("c")).to be true
    end

    it "recognizes 'finish' as a debug command" do
      expect(described_class.debug_command?("finish")).to be true
    end

    it "recognizes 'break' as a debug command" do
      expect(described_class.debug_command?("break")).to be true
    end

    it "recognizes 'break' with arguments as a debug command" do
      expect(described_class.debug_command?("break sample.rb:14")).to be true
    end

    it "recognizes 'backtrace' as a debug command" do
      expect(described_class.debug_command?("backtrace")).to be true
    end

    it "recognizes 'bt' as a debug command" do
      expect(described_class.debug_command?("bt")).to be true
    end

    it "recognizes 'info' as a debug command" do
      expect(described_class.debug_command?("info")).to be true
    end

    it "recognizes 'debug' as a debug command" do
      expect(described_class.debug_command?("debug")).to be true
    end

    it "does not recognize regular Ruby code" do
      expect(described_class.debug_command?("x = 1")).to be false
    end

    it "does not recognize empty string" do
      expect(described_class.debug_command?("")).to be false
    end

    it "handles commands with leading whitespace" do
      expect(described_class.debug_command?("  next")).to be true
    end

    it "is case insensitive" do
      expect(described_class.debug_command?("NEXT")).to be true
      expect(described_class.debug_command?("Step")).to be true
    end
  end

  describe "pending IRB commands" do
    before(:each) do
      described_class.take_pending_irb_commands
    end

    describe ".add_pending_irb_command" do
      it "adds a command to the queue" do
        described_class.add_pending_irb_command("next")
        expect(described_class.pending_irb_commands).to include("next")
      end
    end

    describe ".take_pending_irb_commands" do
      it "returns and clears pending commands" do
        described_class.add_pending_irb_command("step")
        described_class.add_pending_irb_command("next")

        cmds = described_class.take_pending_irb_commands
        expect(cmds).to eq(["step", "next"])
        expect(described_class.pending_irb_commands).to be_empty
      end

      it "returns empty array when no pending commands" do
        expect(described_class.take_pending_irb_commands).to eq([])
      end
    end
  end

  describe "pending input commands" do
    before(:each) do
      # Clear any pending input
      while described_class.has_pending_input?
        described_class.take_next_input_command
      end
    end

    describe ".add_pending_input_command" do
      it "adds a command for IRB input injection" do
        described_class.add_pending_input_command("next")
        expect(described_class.has_pending_input?).to be true
      end
    end

    describe ".take_next_input_command" do
      it "returns commands in FIFO order" do
        described_class.add_pending_input_command("first")
        described_class.add_pending_input_command("second")

        expect(described_class.take_next_input_command).to eq("first")
        expect(described_class.take_next_input_command).to eq("second")
      end

      it "returns nil when queue is empty" do
        expect(described_class.take_next_input_command).to be_nil
      end
    end

    describe ".has_pending_input?" do
      it "returns false when no pending input" do
        expect(described_class.has_pending_input?).to be false
      end

      it "returns true when there is pending input" do
        described_class.add_pending_input_command("cmd")
        expect(described_class.has_pending_input?).to be true
      end
    end
  end

  describe ".pending_user_question" do
    it "stores and retrieves the user question" do
      described_class.pending_user_question = "What is this?"
      expect(described_class.pending_user_question).to eq("What is this?")
      described_class.pending_user_question = nil
    end
  end

  describe "DEBUG_COMMANDS" do
    it "includes standard debug commands" do
      expected = %w[next n step s continue c finish break delete backtrace bt info catch debug]
      expect(described_class::DEBUG_COMMANDS).to eq(expected)
    end
  end
end
