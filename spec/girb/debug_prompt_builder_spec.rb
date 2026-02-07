# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::DebugPromptBuilder do
  let(:question) { "What is the value of x?" }
  let(:context) do
    {
      source_location: { file: "/app/sample.rb", line: 10 },
      local_variables: { x: "42", y: '"hello"' },
      instance_variables: { :@name => '"test"' },
      self_info: { class: "MyClass", inspect: "#<MyClass:0x123>", methods: [:foo, :bar] },
      backtrace: "sample.rb:10:in `method_a'",
      session_history: "[cmd] next\n[cmd] step"
    }
  end

  subject { described_class.new(question, context) }

  describe "#system_prompt" do
    it "includes debugging assistant identity" do
      expect(subject.system_prompt).to include("AI debugging assistant")
    end

    it "includes debugger command documentation" do
      prompt = subject.system_prompt
      expect(prompt).to include("step")
      expect(prompt).to include("next")
      expect(prompt).to include("continue")
      expect(prompt).to include("run_debug_command")
    end

    it "includes tool descriptions" do
      expect(subject.system_prompt).to include("evaluate_code")
    end

    it "includes auto_continue documentation" do
      expect(subject.system_prompt).to include("auto_continue")
    end

    it "includes breakpoint line placement rules for block bodies" do
      prompt = subject.system_prompt
      expect(prompt).to include("NEVER place a breakpoint on a block header line")
      expect(prompt).to include("ALWAYS place breakpoints on a line INSIDE the block body")
    end

    it "includes evaluate_code alternative for tracking scenarios" do
      prompt = subject.system_prompt
      expect(prompt).to include("evaluate_code for pure tracking scenarios")
      expect(prompt).to include("catch(:girb_stop)")
    end

    it "requires continue immediately after setting breakpoint" do
      prompt = subject.system_prompt
      expect(prompt).to include("MUST continue immediately after setting the breakpoint")
      expect(prompt).to include("do NOT stop and wait for user input")
    end

    context "with custom prompt" do
      before do
        Girb.configure do |c|
          c.custom_prompt = "Focus on performance"
        end
      end

      it "includes custom prompt" do
        expect(subject.system_prompt).to include("Focus on performance")
      end

      it "includes user-defined instructions header" do
        expect(subject.system_prompt).to include("User-Defined Instructions")
      end
    end

    context "with nil custom prompt" do
      before do
        Girb.configure do |c|
          c.custom_prompt = nil
        end
      end

      it "does not include user-defined instructions header" do
        expect(subject.system_prompt).not_to include("User-Defined Instructions")
      end
    end

    context "with empty custom prompt" do
      before do
        Girb.configure do |c|
          c.custom_prompt = ""
        end
      end

      it "does not include user-defined instructions header" do
        expect(subject.system_prompt).not_to include("User-Defined Instructions")
      end
    end
  end

  describe "#user_message" do
    it "includes the question" do
      expect(subject.user_message).to include("What is the value of x?")
    end

    it "includes source location" do
      msg = subject.user_message
      expect(msg).to include("/app/sample.rb")
      expect(msg).to include("10")
    end

    it "includes local variables" do
      msg = subject.user_message
      expect(msg).to include("x: 42")
      expect(msg).to include("y: \"hello\"")
    end

    it "includes instance variables" do
      expect(subject.user_message).to include("@name: \"test\"")
    end

    it "includes self info" do
      msg = subject.user_message
      expect(msg).to include("MyClass")
      expect(msg).to include("#<MyClass:0x123>")
    end

    it "includes backtrace" do
      expect(subject.user_message).to include("sample.rb:10:in `method_a'")
    end

    it "includes session history" do
      expect(subject.user_message).to include("[cmd] next")
    end

    context "with nil/empty context values" do
      let(:context) do
        {
          source_location: nil,
          local_variables: nil,
          instance_variables: nil,
          self_info: nil,
          backtrace: nil,
          session_history: nil
        }
      end

      it "shows placeholders for missing data" do
        msg = subject.user_message
        expect(msg).to include("(unknown)")
        expect(msg).to include("(none)")
        expect(msg).to include("(not available)")
        expect(msg).to include("(no history yet)")
      end
    end

    context "with empty local variables" do
      let(:context) do
        {
          source_location: { file: "test.rb", line: 1 },
          local_variables: {},
          instance_variables: {},
          self_info: { class: "Object", inspect: "main", methods: [] },
          backtrace: nil,
          session_history: ""
        }
      end

      it "shows (none) for empty variables" do
        msg = subject.user_message
        expect(msg).to include("(none)")
      end
    end

    context "with self_info methods" do
      let(:context) do
        {
          source_location: nil,
          local_variables: {},
          instance_variables: {},
          self_info: { class: "Foo", inspect: "#<Foo>", methods: [:hello, :world] },
          backtrace: nil,
          session_history: nil
        }
      end

      it "includes defined methods" do
        msg = subject.user_message
        expect(msg).to include("hello, world")
      end
    end
  end
end
