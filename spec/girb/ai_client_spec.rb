# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::AiClient do
  let(:provider) { double("provider") }
  let(:response_class) { Girb::Providers::Base::Response }
  let(:test_binding) { binding }

  before(:each) do
    Girb.configure do |c|
      c.provider = provider
    end
  end

  describe "#initialize" do
    it "requires a configured provider" do
      Girb.configuration = nil
      Girb.configure  # no provider
      expect { described_class.new }.to raise_error(Girb::ConfigurationError)
    end

    it "succeeds with a provider" do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe "#ask" do
    let(:client) { described_class.new }
    let(:context) do
      {
        source_location: { file: "(irb)", line: 1 },
        local_variables: {},
        last_value: nil,
        last_exception: nil,
        session_history: [],
        method_definitions: []
      }
    end

    context "with a text response" do
      before do
        allow(provider).to receive(:chat).and_return(
          response_class.new(text: "The answer is 42")
        )
      end

      it "outputs the response text" do
        expect { client.ask("What is x?", context, binding: test_binding) }.to output(
          /The answer is 42/
        ).to_stdout
      end

      it "adds user message to conversation history" do
        client.ask("What is x?", context, binding: test_binding)
        messages = Girb::ConversationHistory.messages
        expect(messages.first.role).to eq("user")
      end

      it "adds assistant message to conversation history" do
        client.ask("What is x?", context, binding: test_binding)
        messages = Girb::ConversationHistory.messages
        expect(messages.last.role).to eq("model")
        expect(messages.last.content).to eq("The answer is 42")
      end
    end

    context "with a tool call response" do
      before do
        # First call returns a tool call, second returns text
        call_count = 0
        allow(provider).to receive(:chat) do
          call_count += 1
          if call_count == 1
            response_class.new(
              function_calls: [
                { name: "evaluate_code", args: { "code" => "1 + 1" }, id: "call_1" }
              ]
            )
          else
            response_class.new(text: "The result is 2")
          end
        end
      end

      it "executes the tool and continues" do
        expect { client.ask("What is 1+1?", context, binding: test_binding) }.to output(
          /The result is 2/
        ).to_stdout
      end

      it "calls provider multiple times" do
        client.ask("What is 1+1?", context, binding: test_binding)
        expect(provider).to have_received(:chat).exactly(2).times
      end
    end

    context "with auto-continue" do
      before do
        call_count = 0
        allow(provider).to receive(:chat) do
          call_count += 1
          if call_count == 1
            # First call: tool calls continue_analysis
            response_class.new(
              function_calls: [
                { name: "continue_analysis", args: { "reason" => "need context" }, id: "call_1" }
              ]
            )
          elsif call_count == 2
            # After tool call, return text to end tool loop
            response_class.new(text: "Continuing...")
          else
            # Auto-continue re-invocation
            response_class.new(text: "Final answer")
          end
        end
      end

      it "re-invokes when auto-continue is active" do
        # Stub context builder for auto-continue re-invocation
        context_builder = double("context_builder", build: context)
        allow(Girb::ContextBuilder).to receive(:new).and_return(context_builder)

        expect { client.ask("Investigate", context, binding: test_binding) }.to output(
          /Final answer/
        ).to_stdout
      end
    end

    context "with error response" do
      before do
        allow(provider).to receive(:chat).and_return(
          response_class.new(error: "API rate limit exceeded")
        )
      end

      it "outputs the error" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /API Error/
        ).to_stdout
      end
    end

    context "with nil response" do
      before do
        allow(provider).to receive(:chat).and_return(nil)
      end

      it "handles nil response gracefully" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /No response/
        ).to_stdout
      end
    end

    context "with unknown tool" do
      before do
        call_count = 0
        allow(provider).to receive(:chat) do
          call_count += 1
          if call_count == 1
            response_class.new(
              function_calls: [
                { name: "nonexistent_tool", args: {}, id: "call_1" }
              ]
            )
          else
            response_class.new(text: "Done")
          end
        end
      end

      it "returns error for unknown tool and continues" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /Done/
        ).to_stdout
      end
    end

    context "with MAX_TOOL_ITERATIONS limit" do
      before do
        # Always return tool calls to hit the limit
        allow(provider).to receive(:chat).and_return(
          response_class.new(
            function_calls: [
              { name: "evaluate_code", args: { "code" => "1" }, id: "call_n" }
            ]
          )
        )
      end

      it "stops after MAX_TOOL_ITERATIONS" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /Tool iteration limit/
        ).to_stdout
        expect(provider).to have_received(:chat).exactly(described_class::MAX_TOOL_ITERATIONS).times
      end
    end

    context "in debug mode" do
      let(:debug_context) do
        {
          source_location: { file: "test.rb", line: 10 },
          local_variables: { x: "42" },
          instance_variables: {},
          self_info: { class: "Object", inspect: "main", methods: [] },
          backtrace: nil,
          session_history: nil
        }
      end

      before do
        allow(provider).to receive(:chat).and_return(
          response_class.new(text: "Debug info")
        )
      end

      it "uses DebugPromptBuilder in debug mode" do
        expect(Girb::DebugPromptBuilder).to receive(:new).and_call_original
        client.ask("What is x?", debug_context, binding: test_binding, debug_mode: true)
      end

      it "outputs response" do
        expect { client.ask("What?", debug_context, binding: test_binding, debug_mode: true) }.to output(
          /Debug info/
        ).to_stdout
      end
    end

    context "with text alongside tool calls" do
      before do
        call_count = 0
        allow(provider).to receive(:chat) do
          call_count += 1
          if call_count == 1
            response_class.new(
              text: "Let me check...",
              function_calls: [
                { name: "evaluate_code", args: { "code" => "42" }, id: "call_1" }
              ]
            )
          else
            response_class.new(text: "The answer is 42")
          end
        end
      end

      it "accumulates and outputs text from tool calls" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /The answer is 42/
        ).to_stdout
      end
    end

    context "with Interrupt during API call" do
      before do
        allow(provider).to receive(:chat).and_raise(Interrupt)
      end

      it "handles interrupt gracefully" do
        expect { client.ask("test", context, binding: test_binding) }.to output(
          /Interrupted/
        ).to_stdout
      end
    end

    context "with auto-continue interrupt" do
      before do
        call_count = 0
        allow(provider).to receive(:chat) do
          call_count += 1
          if call_count == 1
            Girb::AutoContinue.request!
            Girb::AutoContinue.interrupt!
            response_class.new(text: "First response")
          else
            response_class.new(text: "Should not reach")
          end
        end

        context_builder = double("context_builder", build: context)
        allow(Girb::ContextBuilder).to receive(:new).and_return(context_builder)
      end

      it "stops auto-continue loop on interrupt" do
        client.ask("test", context, binding: test_binding)
        # Should have been called more than once (initial + interrupt summary),
        # but not endlessly
        expect(provider).to have_received(:chat).at_most(3).times
      end
    end
  end

  describe "MAX_TOOL_ITERATIONS" do
    it "is set to 10" do
      expect(described_class::MAX_TOOL_ITERATIONS).to eq(10)
    end
  end
end
