# frozen_string_literal: true

require "spec_helper"
require "girb/tools/run_debug_command"

RSpec.describe Girb::Tools::RunDebugCommand do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  # Mock DebugIntegration module
  before(:each) do
    debug_integration = Module.new do
      class << self
        attr_accessor :auto_continue
        def add_pending_debug_command(cmd)
          @pending_commands ||= []
          @pending_commands << cmd
        end
        def pending_commands
          @pending_commands || []
        end
      end
    end
    stub_const("Girb::DebugIntegration", debug_integration)
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("debugger")
    end
  end

  describe ".parameters" do
    it "includes command as required" do
      params = described_class.parameters
      expect(params[:required]).to include("command")
    end

    it "includes auto_continue parameter" do
      expect(described_class.parameters[:properties]).to have_key(:auto_continue)
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

  describe "#execute" do
    it "adds command to pending debug commands" do
      tool.execute(test_binding, command: "next")
      expect(Girb::DebugIntegration.pending_commands).to include("next")
    end

    it "returns success response" do
      result = tool.execute(test_binding, command: "step")
      expect(result[:success]).to be true
      expect(result[:command]).to eq("step")
    end

    it "sets auto_continue on DebugIntegration when true" do
      tool.execute(test_binding, command: "next", auto_continue: true)
      expect(Girb::DebugIntegration.auto_continue).to be true
    end

    it "does not set auto_continue when false" do
      tool.execute(test_binding, command: "next", auto_continue: false)
      expect(Girb::DebugIntegration.auto_continue).to be_nil
    end

    it "returns auto_continue status in response" do
      result = tool.execute(test_binding, command: "continue", auto_continue: true)
      expect(result[:auto_continue]).to be true
    end

    it "includes message about re-invocation when auto_continue" do
      result = tool.execute(test_binding, command: "next", auto_continue: true)
      expect(result[:message]).to include("re-invoked")
    end

    it "includes message about execution when not auto_continue" do
      result = tool.execute(test_binding, command: "next", auto_continue: false)
      expect(result[:message]).to include("executed after")
    end
  end
end
