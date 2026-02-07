# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::RunIrbDebugCommand do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  # Mock IrbIntegration module
  before(:each) do
    irb_integration = Module.new do
      class << self
        def add_pending_irb_command(cmd)
          @pending_commands ||= []
          @pending_commands << cmd
        end
        def pending_commands
          @pending_commands || []
        end
      end
    end
    stub_const("Girb::IrbIntegration", irb_integration)
  end

  describe ".name" do
    it "returns run_debug_command" do
      expect(described_class.name).to eq("run_debug_command")
    end
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("debug")
    end
  end

  describe ".parameters" do
    it "includes command as required" do
      expect(described_class.parameters[:required]).to include("command")
    end

    it "includes auto_continue parameter" do
      expect(described_class.parameters[:properties]).to have_key(:auto_continue)
    end
  end

  describe ".available?" do
    it "returns true when IRB is defined and DEBUGGER__::SESSION is not" do
      # IRB is already stubbed in spec_helper
      expect(described_class.available?).to be true
    end

    context "when DEBUGGER__::SESSION is defined" do
      before do
        debugger_mod = Module.new do
          const_set(:SESSION, Object.new)
        end
        stub_const("DEBUGGER__", debugger_mod)
      end

      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  describe "#execute" do
    it "adds command to pending IRB commands" do
      tool.execute(test_binding, command: "next")
      expect(Girb::IrbIntegration.pending_commands).to include("next")
    end

    it "returns success response" do
      result = tool.execute(test_binding, command: "step")
      expect(result[:success]).to be true
      expect(result[:command]).to eq("step")
    end

    it "requests AutoContinue when auto_continue is true" do
      tool.execute(test_binding, command: "next", auto_continue: true)
      expect(Girb::AutoContinue.active?).to be true
    end

    it "does not request AutoContinue when auto_continue is false" do
      tool.execute(test_binding, command: "next", auto_continue: false)
      expect(Girb::AutoContinue.active?).to be false
    end

    it "returns auto_continue status" do
      result = tool.execute(test_binding, command: "continue", auto_continue: true)
      expect(result[:auto_continue]).to be true
    end

    it "includes appropriate message" do
      result = tool.execute(test_binding, command: "next", auto_continue: false)
      expect(result[:message]).to include("executed after")
    end
  end
end
