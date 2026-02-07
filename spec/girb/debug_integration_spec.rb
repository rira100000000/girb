# frozen_string_literal: true

require "spec_helper"

# Load debug_integration without requiring the "debug" gem,
# which would define DEBUGGER__ and contaminate other specs
$LOADED_FEATURES << "debug.rb" unless $LOADED_FEATURES.any? { |f| f.end_with?("/debug.rb") || f == "debug.rb" }
require "girb/debug_integration"

RSpec.describe Girb::DebugIntegration::GirbDebugCommands do
  # Create a test host class that includes the module under test
  let(:host_class) do
    Class.new do
      include Girb::DebugIntegration::GirbDebugCommands

      attr_accessor :tc

      # Make private methods accessible for testing
      public :handle_ai_question, :with_timeout_disabled
    end
  end

  let(:mock_binding) { binding }
  let(:mock_frame) { double("frame", eval_binding: mock_binding) }
  let(:mock_tc) { double("thread_client", current_frame: mock_frame) }
  let(:mock_context) { { source_location: { file: "test.rb", line: 1 }, local_variables: {} } }
  let(:mock_client) { instance_double(Girb::AiClient) }

  let(:instance) do
    obj = host_class.new
    obj.tc = mock_tc
    obj
  end

  before(:each) do
    Girb.configure
    Girb::DebugIntegration.instance_variable_set(:@session_started, false)
    Girb::DebugIntegration.auto_continue = false
    Girb::DebugIntegration.clear_interrupt!
    Girb::DebugIntegration.instance_variable_set(:@pending_debug_commands, [])

    allow(Girb::DebugContextBuilder).to receive(:new).and_return(double(build: mock_context))
    allow(Girb::AiClient).to receive(:new).and_return(mock_client)
    allow(mock_client).to receive(:ask)
    allow(Girb::SessionPersistence).to receive(:start_session)
  end

  describe "#handle_ai_question" do
    context "interrupt protection" do
      it "installs a SIGINT trap during API call" do
        handler_installed = false
        allow(mock_client).to receive(:ask) do
          # During API call, sending SIGINT should set the flag, not crash
          Process.kill("INT", Process.pid)
          # Give signal a moment to be processed
          sleep 0.01
          handler_installed = Girb::DebugIntegration.interrupted?
        end

        instance.handle_ai_question("test question")

        expect(handler_installed).to be true
      end

      it "clears pending debug commands when interrupted" do
        Girb::DebugIntegration.add_pending_debug_command("next")
        Girb::DebugIntegration.add_pending_debug_command("step")

        allow(mock_client).to receive(:ask) do
          Girb::DebugIntegration.interrupt!
        end

        instance.handle_ai_question("test question")

        expect(Girb::DebugIntegration.pending_debug_commands).to be_empty
      end

      it "sets auto_continue to false when interrupted" do
        Girb::DebugIntegration.auto_continue = true

        allow(mock_client).to receive(:ask) do
          Girb::DebugIntegration.interrupt!
        end

        instance.handle_ai_question("test question")

        expect(Girb::DebugIntegration.auto_continue).to be false
      end

      it "prints interrupted message when interrupted" do
        allow(mock_client).to receive(:ask) do
          Girb::DebugIntegration.interrupt!
        end

        expect { instance.handle_ai_question("test question") }
          .to output(/Interrupted by user/).to_stdout
      end

      it "clears the interrupt flag after handling" do
        allow(mock_client).to receive(:ask) do
          Girb::DebugIntegration.interrupt!
        end

        instance.handle_ai_question("test question")

        expect(Girb::DebugIntegration.interrupted?).to be false
      end
    end

    context "handler restoration" do
      it "restores the original SIGINT handler after normal execution" do
        original_handler = trap("INT", "DEFAULT")
        trap("INT", original_handler) if original_handler

        instance.handle_ai_question("test question")

        # After handle_ai_question, the handler should be restored
        current_handler = trap("INT", "DEFAULT")
        trap("INT", current_handler) if current_handler

        # Both should be DEFAULT (or the same handler)
        expect(Girb::DebugIntegration.interrupted?).to be false
      end

      it "restores the original SIGINT handler after an error" do
        custom_handler_called = false
        original = trap("INT") { custom_handler_called = true }

        allow(mock_client).to receive(:ask).and_raise(StandardError, "API error")

        instance.handle_ai_question("test question")

        # The custom handler should be restored
        Process.kill("INT", Process.pid)
        sleep 0.01

        expect(custom_handler_called).to be true
      ensure
        trap("INT", original) if original
      end

      it "restores the original SIGINT handler after ConfigurationError" do
        custom_handler_called = false
        original = trap("INT") { custom_handler_called = true }

        allow(mock_client).to receive(:ask).and_raise(Girb::ConfigurationError, "config error")

        instance.handle_ai_question("test question")

        Process.kill("INT", Process.pid)
        sleep 0.01

        expect(custom_handler_called).to be true
      ensure
        trap("INT", original) if original
      end
    end

    context "when no current frame is available" do
      let(:mock_tc) { double("thread_client", current_frame: nil) }

      it "prints error and returns without installing trap" do
        expect { instance.handle_ai_question("test") }
          .to output(/No current frame available/).to_stdout
      end
    end

    context "normal operation" do
      it "calls AiClient.ask with question and context" do
        expect(mock_client).to receive(:ask).with(
          "test question", mock_context, binding: mock_binding, debug_mode: true
        )

        instance.handle_ai_question("test question")
      end

      it "starts a debug session" do
        expect(Girb::SessionPersistence).to receive(:start_session)

        instance.handle_ai_question("test question")
      end

      it "does not print interrupted message when not interrupted" do
        expect { instance.handle_ai_question("test question") }
          .not_to output(/Interrupted/).to_stdout
      end
    end
  end
end
