# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::DebugContextBuilder do
  let(:test_binding) { binding }
  let(:thread_client) { nil }

  subject { described_class.new(test_binding, thread_client: thread_client) }

  describe "#build" do
    it "returns a hash with expected keys" do
      result = subject.build
      expect(result).to be_a(Hash)
      expect(result).to have_key(:source_location)
      expect(result).to have_key(:local_variables)
      expect(result).to have_key(:instance_variables)
      expect(result).to have_key(:self_info)
      expect(result).to have_key(:backtrace)
      expect(result).to have_key(:breakpoint_info)
      expect(result).to have_key(:session_history)
    end
  end

  describe "capture_locals" do
    it "captures local variables from binding" do
      local_var = 42
      b = binding
      builder = described_class.new(b, thread_client: nil)
      result = builder.build

      expect(result[:local_variables]).to have_key(:local_var)
      expect(result[:local_variables][:local_var]).to eq("42")
    end

    it "captures multiple local variables" do
      a = "hello"
      b_var = [1, 2, 3]
      b = binding
      builder = described_class.new(b, thread_client: nil)
      result = builder.build

      expect(result[:local_variables]).to have_key(:a)
      expect(result[:local_variables]).to have_key(:b_var)
    end
  end

  describe "capture_instance_variables" do
    it "captures instance variables of the receiver" do
      obj = Object.new
      obj.instance_variable_set(:@test_var, "value")
      b = obj.instance_eval { binding }
      builder = described_class.new(b, thread_client: nil)
      result = builder.build

      expect(result[:instance_variables]).to have_key(:@test_var)
      expect(result[:instance_variables][:@test_var]).to include("value")
    end
  end

  describe "capture_source_location" do
    it "captures file and line from binding" do
      b = binding
      result = described_class.new(b, thread_client: nil).build

      expect(result[:source_location]).to be_a(Hash)
      expect(result[:source_location][:file]).to include("debug_context_builder_spec.rb")
      expect(result[:source_location][:line]).to be_a(Integer)
    end
  end

  describe "capture_self" do
    it "captures self class and inspect" do
      result = subject.build
      expect(result[:self_info]).to be_a(Hash)
      expect(result[:self_info][:class]).to be_a(String)
      expect(result[:self_info]).to have_key(:inspect)
      expect(result[:self_info]).to have_key(:methods)
    end
  end

  describe "capture_backtrace" do
    context "without thread_client" do
      it "returns nil" do
        expect(subject.build[:backtrace]).to be_nil
      end
    end

    context "with thread_client" do
      let(:frame) { double("frame", location: double("location", to_s: "test.rb:10:in `foo'")) }
      let(:thread_client) { double("thread_client", current_frame: frame) }

      it "captures backtrace from thread client" do
        expect(subject.build[:backtrace]).to eq("test.rb:10:in `foo'")
      end
    end

    context "with thread_client that raises" do
      let(:thread_client) { double("thread_client") }

      before do
        allow(thread_client).to receive(:current_frame).and_raise(StandardError, "connection lost")
      end

      it "returns nil on error" do
        expect(subject.build[:backtrace]).to be_nil
      end
    end
  end

  describe "capture_session_history" do
    it "returns formatted debug session history" do
      Girb::DebugSessionHistory.record_command("next")
      Girb::DebugSessionHistory.record_command("step")

      result = subject.build
      expect(result[:session_history]).to include("[cmd] next")
      expect(result[:session_history]).to include("[cmd] step")
    end
  end

  describe "safe_inspect" do
    it "truncates long inspect output" do
      long_array = (1..1000).to_a
      b = binding
      builder = described_class.new(b, thread_client: nil)
      result = builder.build

      value = result[:local_variables][:long_array]
      expect(value.length).to be <= described_class::MAX_INSPECT_LENGTH + 10 # allow for "..."
    end

    it "handles objects with failing inspect" do
      bad_obj = Object.new
      def bad_obj.inspect
        raise "inspect broken"
      end
      b = binding
      builder = described_class.new(b, thread_client: nil)
      result = builder.build

      expect(result[:local_variables][:bad_obj]).to include("inspect failed")
    end
  end

  describe "MAX_INSPECT_LENGTH" do
    it "is set to 500" do
      expect(described_class::MAX_INSPECT_LENGTH).to eq(500)
    end
  end
end
