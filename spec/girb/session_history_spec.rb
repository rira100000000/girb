# frozen_string_literal: true

require "spec_helper"

RSpec.describe Girb::SessionHistory do
  before(:each) do
    described_class.reset!
  end

  describe ".record" do
    it "records entries with line numbers" do
      described_class.record(1, "x = 1")
      described_class.record(2, "y = 2")

      expect(described_class.entries.size).to eq(2)
      expect(described_class.entries[0].line_no).to eq(1)
      expect(described_class.entries[0].code).to eq("x = 1")
    end

    it "tracks method definitions" do
      described_class.record(1, "def hello")
      described_class.record(2, '  puts "hi"')
      described_class.record(3, "end")

      expect(described_class.method_definitions.size).to eq(1)
      method_def = described_class.method_definitions.first
      expect(method_def.name).to eq("hello")
      expect(method_def.start_line).to eq(1)
      expect(method_def.end_line).to eq(3)
      expect(method_def.code).to include("def hello")
    end
  end

  describe ".find_by_line" do
    it "finds entry by line number" do
      described_class.record(5, "x = 1")
      described_class.record(6, "y = 2")

      entry = described_class.find_by_line(5)
      expect(entry.code).to eq("x = 1")
    end

    it "returns nil for non-existent line" do
      described_class.record(1, "x = 1")

      expect(described_class.find_by_line(999)).to be_nil
    end
  end

  describe ".find_by_line_range" do
    it "finds entries in range" do
      described_class.record(1, "a = 1")
      described_class.record(2, "b = 2")
      described_class.record(3, "c = 3")
      described_class.record(4, "d = 4")

      entries = described_class.find_by_line_range(2, 3)
      expect(entries.size).to eq(2)
      expect(entries.map(&:code)).to eq(["b = 2", "c = 3"])
    end
  end

  describe ".find_method" do
    it "finds method by name" do
      described_class.record(1, "def greet(name)")
      described_class.record(2, '  "Hello, #{name}"')
      described_class.record(3, "end")

      method_def = described_class.find_method("greet")
      expect(method_def).not_to be_nil
      expect(method_def.name).to eq("greet")
      expect(method_def.code).to include("def greet(name)")
    end

    it "returns nil for non-existent method" do
      expect(described_class.find_method("nonexistent")).to be_nil
    end
  end

  describe ".all_with_line_numbers" do
    it "returns all entries with line numbers" do
      described_class.record(1, "x = 1")
      described_class.record(2, "y = 2")

      result = described_class.all_with_line_numbers
      expect(result).to eq(["1: x = 1", "2: y = 2"])
    end

    it "formats AI conversations as [USER]... => [AI]..." do
      described_class.record(1, "x = 1")
      described_class.record(2, "これは何？", is_ai_question: true)
      described_class.record_ai_response(2, "変数xに1が代入されています")

      result = described_class.all_with_line_numbers
      expect(result[0]).to eq("1: x = 1")
      expect(result[1]).to include("[USER] これは何？")
      expect(result[1]).to include("[AI] 変数xに1が代入されています")
    end
  end

  describe ".method_index" do
    it "returns method index with line ranges" do
      described_class.record(1, "def foo")
      described_class.record(2, "end")
      described_class.record(3, "def bar")
      described_class.record(4, '  "bar"')
      described_class.record(5, "end")

      index = described_class.method_index
      expect(index).to include("foo: 1-2行目")
      expect(index).to include("bar: 3-5行目")
    end
  end

  describe "method name extraction" do
    it "handles method names with ?" do
      described_class.record(1, "def valid?")
      described_class.record(2, "end")

      method_def = described_class.find_method("valid?")
      expect(method_def).not_to be_nil
    end

    it "handles method names with !" do
      described_class.record(1, "def save!")
      described_class.record(2, "end")

      method_def = described_class.find_method("save!")
      expect(method_def).not_to be_nil
    end

    it "handles method names with =" do
      described_class.record(1, "def value=(v)")
      described_class.record(2, "end")

      method_def = described_class.find_method("value=")
      expect(method_def).not_to be_nil
    end
  end
end
