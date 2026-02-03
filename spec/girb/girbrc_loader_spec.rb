# frozen_string_literal: true

require "spec_helper"
require "girb/girbrc_loader"
require "tmpdir"
require "fileutils"

RSpec.describe Girb::GirbrcLoader do
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = Pathname.new(tmpdir)
      example.run
    end
  end

  describe ".find_girbrc" do
    context "when .girbrc exists in start directory" do
      it "returns the path to .girbrc" do
        girbrc = @tmpdir.join(".girbrc")
        FileUtils.touch(girbrc)

        result = described_class.find_girbrc(@tmpdir)

        expect(result).to eq(girbrc)
      end
    end

    context "when .girbrc exists in parent directory" do
      it "returns the path to parent's .girbrc" do
        parent_girbrc = @tmpdir.join(".girbrc")
        FileUtils.touch(parent_girbrc)

        child_dir = @tmpdir.join("child")
        FileUtils.mkdir_p(child_dir)

        result = described_class.find_girbrc(child_dir)

        expect(result).to eq(parent_girbrc)
      end
    end

    context "when .girbrc exists in grandparent directory" do
      it "returns the path to grandparent's .girbrc" do
        grandparent_girbrc = @tmpdir.join(".girbrc")
        FileUtils.touch(grandparent_girbrc)

        grandchild_dir = @tmpdir.join("child", "grandchild")
        FileUtils.mkdir_p(grandchild_dir)

        result = described_class.find_girbrc(grandchild_dir)

        expect(result).to eq(grandparent_girbrc)
      end
    end

    context "when .girbrc exists in both current and parent" do
      it "returns the current directory's .girbrc (nearest)" do
        parent_girbrc = @tmpdir.join(".girbrc")
        FileUtils.touch(parent_girbrc)

        child_dir = @tmpdir.join("child")
        FileUtils.mkdir_p(child_dir)
        child_girbrc = child_dir.join(".girbrc")
        FileUtils.touch(child_girbrc)

        result = described_class.find_girbrc(child_dir)

        expect(result).to eq(child_girbrc)
      end
    end

    context "when no .girbrc exists in directory tree" do
      it "falls back to ~/.girbrc if it exists" do
        home_girbrc = Pathname.new(File.expand_path("~/.girbrc"))

        if home_girbrc.exist?
          result = described_class.find_girbrc(@tmpdir)
          expect(result).to eq(home_girbrc)
        else
          # Create a temporary home girbrc for testing
          begin
            FileUtils.touch(home_girbrc)
            result = described_class.find_girbrc(@tmpdir)
            expect(result).to eq(home_girbrc)
          ensure
            FileUtils.rm_f(home_girbrc)
          end
        end
      end

      it "returns nil if ~/.girbrc also doesn't exist" do
        home_girbrc = Pathname.new(File.expand_path("~/.girbrc"))

        # Skip if ~/.girbrc exists (user's actual config)
        skip "~/.girbrc exists" if home_girbrc.exist?

        result = described_class.find_girbrc(@tmpdir)

        expect(result).to be_nil
      end
    end
  end

  describe ".load_girbrc" do
    context "when .girbrc exists and is valid" do
      it "loads the file and returns true" do
        girbrc = @tmpdir.join(".girbrc")
        girbrc.write("$girbrc_loaded = true")

        result = described_class.load_girbrc(@tmpdir)

        expect(result).to be true
        expect($girbrc_loaded).to be true
      ensure
        $girbrc_loaded = nil
      end
    end

    context "when .girbrc doesn't exist" do
      it "returns false" do
        home_girbrc = Pathname.new(File.expand_path("~/.girbrc"))
        skip "~/.girbrc exists" if home_girbrc.exist?

        result = described_class.load_girbrc(@tmpdir)

        expect(result).to be false
      end
    end

    context "when .girbrc has a syntax error" do
      it "returns false and prints a warning" do
        girbrc = @tmpdir.join(".girbrc")
        girbrc.write("this is not valid ruby {{{")

        expect {
          result = described_class.load_girbrc(@tmpdir)
          expect(result).to be false
        }.to output(/Error loading/).to_stderr
      end
    end

    context "when .girbrc raises LoadError" do
      it "returns false and prints a warning" do
        girbrc = @tmpdir.join(".girbrc")
        girbrc.write("require 'nonexistent_gem_12345'")

        expect {
          result = described_class.load_girbrc(@tmpdir)
          expect(result).to be false
        }.to output(/Error loading/).to_stderr
      end
    end

    context "when debug mode is enabled" do
      it "prints the loading path" do
        Girb.configure { |c| c.debug = true }

        girbrc = @tmpdir.join(".girbrc")
        girbrc.write("# empty")

        expect {
          described_class.load_girbrc(@tmpdir)
        }.to output(/Loading.*\.girbrc/).to_stderr
      end
    end
  end
end
