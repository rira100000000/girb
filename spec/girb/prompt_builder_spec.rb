# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::PromptBuilder do
  let(:question) { "What is x?" }
  let(:context) do
    {
      source_location: { file: "(irb)", line: 5 },
      local_variables: { x: "1", y: "2" },
      last_value: "3",
      last_exception: nil,
      session_history: ["1: x = 1", "2: y = 2"],
      method_definitions: ["def foo; end"],
      self_info: { class: "Object", inspect: "main", methods: [] }
    }
  end

  subject { described_class.new(question, context) }

  describe "#system_prompt" do
    it "includes common prompt content" do
      expect(subject.system_prompt).to include("You are girb")
    end

    it "includes continue analysis prompt" do
      expect(subject.system_prompt).to include("continue_analysis")
    end

    context "in interactive mode" do
      it "includes interactive IRB prompt" do
        expect(subject.system_prompt).to include("Interactive IRB Session")
      end
    end

    context "in breakpoint mode" do
      let(:context) do
        {
          source_location: { file: "/app/models/user.rb", line: 10 },
          local_variables: {},
          last_value: nil,
          last_exception: nil,
          session_history: [],
          method_definitions: []
        }
      end

      it "includes breakpoint prompt" do
        expect(subject.system_prompt).to include("Breakpoint")
      end
    end

    context "in Rails mode" do
      before do
        stub_const("Rails", Class.new)
      end

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

      it "includes Rails console prompt" do
        expect(subject.system_prompt).to include("Rails Console")
      end
    end

    context "with custom prompt" do
      before do
        Girb.configure do |c|
          c.custom_prompt = "Always respond in Japanese"
        end
      end

      it "includes custom prompt" do
        expect(subject.system_prompt).to include("Always respond in Japanese")
      end

      it "includes user-defined instructions header" do
        expect(subject.system_prompt).to include("User-Defined Instructions")
      end
    end

    context "with empty custom prompt" do
      before do
        Girb.configure do |c|
          c.custom_prompt = ""
        end
      end

      it "does not append user-defined instructions section" do
        expect(subject.system_prompt).not_to include("## User-Defined Instructions\n")
      end
    end
  end

  describe "#user_message" do
    it "includes the question" do
      expect(subject.user_message).to include("What is x?")
    end

    it "includes local variables" do
      msg = subject.user_message
      expect(msg).to include("x: 1")
      expect(msg).to include("y: 2")
    end

    it "includes session history" do
      expect(subject.user_message).to include("1: x = 1")
    end

    it "includes last value" do
      expect(subject.user_message).to include("3")
    end

    it "includes source location" do
      expect(subject.user_message).to include("(irb)")
    end

    it "includes method definitions" do
      expect(subject.user_message).to include("def foo; end")
    end

    context "with no local variables" do
      let(:context) do
        {
          source_location: nil,
          local_variables: nil,
          last_value: nil,
          last_exception: nil,
          session_history: nil,
          method_definitions: nil
        }
      end

      it "shows (none) for missing data" do
        msg = subject.user_message
        expect(msg).to include("(none)")
      end

      it "shows (interactive session) for nil source location" do
        expect(subject.user_message).to include("(interactive session)")
      end
    end

    context "with exception" do
      let(:context) do
        {
          source_location: nil,
          local_variables: {},
          last_value: nil,
          last_exception: {
            class: "NoMethodError",
            message: "undefined method 'foo'",
            time: "2024-01-01",
            backtrace: ["file.rb:1", "file.rb:2"]
          },
          session_history: [],
          method_definitions: []
        }
      end

      it "includes exception details" do
        msg = subject.user_message
        expect(msg).to include("NoMethodError")
        expect(msg).to include("undefined method 'foo'")
      end
    end
  end

  describe "#build" do
    it "returns a combined prompt with system prompt and context" do
      result = subject.build
      expect(result).to include("You are girb")
      expect(result).to include("What is x?")
      expect(result).to include("x: 1")
    end
  end

  describe "detect_mode" do
    context "with irb source" do
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

      it "detects interactive mode" do
        expect(subject.system_prompt).to include("Interactive IRB Session")
      end
    end

    context "with eval source" do
      let(:context) do
        {
          source_location: { file: "(eval)", line: 1 },
          local_variables: {},
          last_value: nil,
          last_exception: nil,
          session_history: [],
          method_definitions: []
        }
      end

      it "detects interactive mode" do
        expect(subject.system_prompt).to include("Interactive IRB Session")
      end
    end

    context "with real file source" do
      let(:context) do
        {
          source_location: { file: "/home/user/app.rb", line: 42 },
          local_variables: {},
          last_value: nil,
          last_exception: nil,
          session_history: [],
          method_definitions: []
        }
      end

      it "detects breakpoint mode" do
        expect(subject.system_prompt).to include("Breakpoint")
      end
    end

    context "with nil source_location" do
      let(:context) do
        {
          source_location: nil,
          local_variables: {},
          last_value: nil,
          last_exception: nil,
          session_history: [],
          method_definitions: []
        }
      end

      it "defaults to interactive mode" do
        expect(subject.system_prompt).to include("Interactive IRB Session")
      end
    end

    context "with nil file in source_location" do
      let(:context) do
        {
          source_location: { file: nil, line: 1 },
          local_variables: {},
          last_value: nil,
          last_exception: nil,
          session_history: [],
          method_definitions: []
        }
      end

      it "defaults to interactive mode" do
        expect(subject.system_prompt).to include("Interactive IRB Session")
      end
    end
  end
end
