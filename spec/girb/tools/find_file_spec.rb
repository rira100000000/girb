# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Girb::Tools::FindFile do
  let(:tool) { described_class.new }
  let(:test_binding) { binding }
  let(:tmpdir) { Dir.mktmpdir }

  before(:each) do
    allow(Dir).to receive(:pwd).and_return(tmpdir)
    allow(Bundler).to receive(:root).and_return(Pathname.new(tmpdir)) if defined?(Bundler)
  end

  after(:each) do
    FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
    end
  end

  describe ".parameters" do
    it "includes pattern as required" do
      params = described_class.parameters
      expect(params[:properties]).to have_key(:pattern)
      expect(params[:required]).to include("pattern")
    end

    it "includes optional directory" do
      expect(described_class.parameters[:properties]).to have_key(:directory)
    end
  end

  describe "#execute" do
    it "finds files matching a pattern" do
      FileUtils.mkdir_p(File.join(tmpdir, "app", "models"))
      File.write(File.join(tmpdir, "app", "models", "user.rb"), "")
      File.write(File.join(tmpdir, "app", "models", "post.rb"), "")

      result = tool.execute(test_binding, pattern: "*.rb")
      expect(result[:files]).to include("app/models/user.rb")
      expect(result[:files]).to include("app/models/post.rb")
    end

    it "returns count of found files" do
      File.write(File.join(tmpdir, "a.rb"), "")
      File.write(File.join(tmpdir, "b.rb"), "")

      result = tool.execute(test_binding, pattern: "*.rb")
      expect(result[:count]).to eq(2)
    end

    it "limits results to MAX_RESULTS" do
      (described_class::MAX_RESULTS + 5).times do |i|
        File.write(File.join(tmpdir, "file#{i}.rb"), "")
      end

      result = tool.execute(test_binding, pattern: "*.rb")
      expect(result[:count]).to eq(described_class::MAX_RESULTS)
      expect(result[:truncated]).to be true
    end

    it "returns relative paths" do
      File.write(File.join(tmpdir, "test.rb"), "")

      result = tool.execute(test_binding, pattern: "test.rb")
      expect(result[:files].first).not_to start_with("/")
    end

    it "searches in specified directory" do
      subdir = File.join(tmpdir, "subdir")
      FileUtils.mkdir_p(subdir)
      File.write(File.join(subdir, "found.rb"), "")
      File.write(File.join(tmpdir, "not_found.rb"), "")

      result = tool.execute(test_binding, pattern: "*.rb", directory: "subdir")
      expect(result[:files]).to include("found.rb")
      expect(result[:files]).not_to include("not_found.rb")
    end

    it "handles glob patterns with directory" do
      FileUtils.mkdir_p(File.join(tmpdir, "app", "models"))
      File.write(File.join(tmpdir, "app", "models", "user.rb"), "")

      result = tool.execute(test_binding, pattern: "app/models/*.rb")
      expect(result[:files]).to include("app/models/user.rb")
    end

    it "returns error for non-existent directory" do
      result = tool.execute(test_binding, pattern: "*.rb", directory: "/nonexistent")
      expect(result[:error]).to include("Directory not found")
    end

    it "returns empty files array when no match" do
      result = tool.execute(test_binding, pattern: "*.xyz")
      expect(result[:files]).to eq([])
      expect(result[:count]).to eq(0)
    end

    it "excludes directories from results" do
      FileUtils.mkdir_p(File.join(tmpdir, "subdir.rb"))
      File.write(File.join(tmpdir, "file.rb"), "")

      result = tool.execute(test_binding, pattern: "*.rb")
      expect(result[:files]).to eq(["file.rb"])
    end
  end

  describe "MAX_RESULTS" do
    it "is set to 20" do
      expect(described_class::MAX_RESULTS).to eq(20)
    end
  end
end
