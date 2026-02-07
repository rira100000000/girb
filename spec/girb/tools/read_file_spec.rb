# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Girb::Tools::ReadFile do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }
  let(:tmpdir) { Dir.mktmpdir }

  after(:each) do
    FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
    end
  end

  describe ".parameters" do
    it "includes path as required" do
      params = described_class.parameters
      expect(params[:properties]).to have_key(:path)
      expect(params[:required]).to include("path")
    end

    it "includes optional start_line and end_line" do
      params = described_class.parameters
      expect(params[:properties]).to have_key(:start_line)
      expect(params[:properties]).to have_key(:end_line)
    end
  end

  describe "#execute" do
    it "reads an entire file" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "line1\nline2\nline3\n")

      result = tool.execute(test_binding, path: file)
      expect(result[:content]).to include("line1")
      expect(result[:content]).to include("line2")
      expect(result[:content]).to include("line3")
      expect(result[:total_lines]).to eq(3)
    end

    it "includes line numbers in output" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "hello\nworld\n")

      result = tool.execute(test_binding, path: file)
      expect(result[:content]).to include("1: hello")
      expect(result[:content]).to include("2: world")
    end

    it "reads a specific line range" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, (1..10).map { |i| "line#{i}" }.join("\n") + "\n")

      result = tool.execute(test_binding, path: file, start_line: 3, end_line: 5)
      expect(result[:content]).to include("line3")
      expect(result[:content]).to include("line5")
      expect(result[:content]).not_to include("line1")
      expect(result[:content]).not_to include("line6")
    end

    it "returns error for non-existent file" do
      result = tool.execute(test_binding, path: "/nonexistent/file.rb")
      expect(result[:error]).to include("File not found")
    end

    it "returns error for too-large files" do
      file = File.join(tmpdir, "large.txt")
      File.write(file, "x" * (described_class::MAX_FILE_SIZE + 1))

      result = tool.execute(test_binding, path: file)
      expect(result[:error]).to include("File too large")
    end

    it "truncates files with many lines" do
      file = File.join(tmpdir, "long.rb")
      File.write(file, (1..600).map { |i| "line#{i}" }.join("\n") + "\n")

      result = tool.execute(test_binding, path: file)
      expect(result[:truncated]).to be true
      expect(result[:lines]).to eq("1-#{described_class::MAX_LINES}")
    end

    it "resolves relative paths from Dir.pwd" do
      file = File.join(tmpdir, "relative.rb")
      File.write(file, "content\n")
      allow(Dir).to receive(:pwd).and_return(tmpdir)
      allow(Bundler).to receive(:root).and_return(nil) if defined?(Bundler)

      result = tool.execute(test_binding, path: "relative.rb")
      expect(result[:content]).to include("content")
    end

    it "handles absolute paths" do
      file = File.join(tmpdir, "absolute.rb")
      File.write(file, "content\n")

      result = tool.execute(test_binding, path: file)
      expect(result[:content]).to include("content")
    end

    it "returns full_path in the result" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "line\n")

      result = tool.execute(test_binding, path: file)
      expect(result[:full_path]).to eq(file)
    end

    it "clamps start_line to minimum 1" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "line1\nline2\n")

      result = tool.execute(test_binding, path: file, start_line: -5, end_line: 1)
      expect(result[:content]).to include("line1")
    end

    it "handles start_line only" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "line1\nline2\nline3\n")

      result = tool.execute(test_binding, path: file, start_line: 2)
      expect(result[:content]).to include("line2")
      expect(result[:content]).to include("line3")
    end

    it "handles end_line only" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "line1\nline2\nline3\n")

      result = tool.execute(test_binding, path: file, end_line: 2)
      expect(result[:content]).to include("line1")
      expect(result[:content]).to include("line2")
      expect(result[:content]).not_to include("3: line3")
    end

    it "returns error for unreadable files" do
      file = File.join(tmpdir, "unreadable.rb")
      File.write(file, "content")
      File.chmod(0o000, file)

      result = tool.execute(test_binding, path: file)
      expect(result[:error]).to include("not readable")

      File.chmod(0o644, file) # cleanup
    end

    it "returns total_lines for all reads" do
      file = File.join(tmpdir, "test.rb")
      File.write(file, "a\nb\nc\nd\ne\n")

      result = tool.execute(test_binding, path: file, start_line: 2, end_line: 3)
      expect(result[:total_lines]).to eq(5)
    end
  end

  describe "constants" do
    it "has MAX_FILE_SIZE" do
      expect(described_class::MAX_FILE_SIZE).to eq(100_000)
    end

    it "has MAX_LINES" do
      expect(described_class::MAX_LINES).to eq(500)
    end
  end
end
