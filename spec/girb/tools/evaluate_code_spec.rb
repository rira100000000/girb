# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::Tools::EvaluateCode do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("Ruby code")
    end
  end

  describe ".parameters" do
    it "includes code parameter" do
      params = described_class.parameters
      expect(params[:properties]).to have_key(:code)
      expect(params[:required]).to include("code")
    end
  end

  describe "#execute" do
    it "executes simple Ruby code" do
      result = tool.execute(test_binding, code: "1 + 1")
      expect(result[:success]).to be true
      expect(result[:result]).to eq("2")
      expect(result[:result_class]).to eq("Integer")
    end

    it "accesses binding variables" do
      x = 42
      b = binding
      result = tool.execute(b, code: "x * 2")
      expect(result[:success]).to be true
      expect(result[:result]).to eq("84")
    end

    it "returns the executed code in the result" do
      result = tool.execute(test_binding, code: "1 + 1")
      expect(result[:code]).to eq("1 + 1")
    end

    it "captures stdout output" do
      result = tool.execute(test_binding, code: 'puts "hello"')
      expect(result[:success]).to be true
      expect(result[:stdout]).to eq("hello\n")
    end

    it "handles SyntaxError" do
      result = tool.execute(test_binding, code: "def foo(")
      expect(result[:success]).to be false
      expect(result[:error]).to include("Syntax error")
    end

    it "handles RuntimeError" do
      result = tool.execute(test_binding, code: 'raise "oops"')
      expect(result[:success]).to be false
      expect(result[:error]).to include("RuntimeError")
      expect(result[:error]).to include("oops")
    end

    it "includes backtrace on error" do
      result = tool.execute(test_binding, code: 'raise "error"')
      expect(result[:backtrace]).to be_an(Array)
      expect(result[:backtrace].length).to be <= 5
    end

    it "handles NameError" do
      result = tool.execute(test_binding, code: "undefined_variable_xyz")
      expect(result[:success]).to be false
      expect(result[:error]).to include("NameError")
    end

    it "restores stdout on error" do
      original_stdout = $stdout
      tool.execute(test_binding, code: 'raise "fail"')
      expect($stdout).to equal(original_stdout)
    end

    it "returns result class name" do
      result = tool.execute(test_binding, code: '"hello"')
      expect(result[:result_class]).to eq("String")
    end

    it "does not include stdout key when no output" do
      result = tool.execute(test_binding, code: "1 + 1")
      expect(result).not_to have_key(:stdout)
    end

    it "captures stdout even on error" do
      result = tool.execute(test_binding, code: 'puts "before"; raise "fail"')
      expect(result[:success]).to be false
      expect(result[:stdout]).to eq("before\n")
    end
  end
end
