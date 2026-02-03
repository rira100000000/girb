# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "girb/girbrc_loader"

RSpec.describe "Girb::Railtie" do
  around(:each) do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = Pathname.new(tmpdir)
      example.run
    end
  end

  describe "console hook behavior" do
    # The Railtie registers a console hook that calls GirbrcLoader.load_girbrc
    # with Rails.root. Since we can't easily test the Railtie registration
    # without a full Rails environment, we test the behavior it should trigger.

    context "when .girbrc exists in Rails.root" do
      it "loads the .girbrc file via GirbrcLoader" do
        girbrc = @tmpdir.join(".girbrc")
        girbrc.write("$railtie_test_loaded = true")

        # Simulate what Railtie does: call load_girbrc with Rails.root
        Girb::GirbrcLoader.load_girbrc(@tmpdir)

        expect($railtie_test_loaded).to be true
      ensure
        $railtie_test_loaded = nil
      end
    end

    context "when .girbrc doesn't exist in Rails.root" do
      it "doesn't raise an error" do
        expect {
          Girb::GirbrcLoader.load_girbrc(@tmpdir)
        }.not_to raise_error
      end

      it "returns false" do
        # Skip if ~/.girbrc exists
        home_girbrc = Pathname.new(File.expand_path("~/.girbrc"))
        skip "~/.girbrc exists" if home_girbrc.exist?

        result = Girb::GirbrcLoader.load_girbrc(@tmpdir)
        expect(result).to be false
      end
    end
  end

  describe "Railtie class" do
    it "is defined when Rails::Railtie is available" do
      # Mock Rails::Railtie with console method
      mock_railtie = Class.new do
        def self.console(&block)
          @console_block = block
        end

        def self.console_block
          @console_block
        end
      end
      stub_const("Rails::Railtie", mock_railtie)

      # Remove existing Girb::Railtie if defined
      Girb.send(:remove_const, :Railtie) if defined?(Girb::Railtie)

      # Load the railtie
      load File.expand_path("../../lib/girb/railtie.rb", __dir__)

      expect(defined?(Girb::Railtie)).to eq("constant")
      expect(Girb::Railtie.superclass).to eq(Rails::Railtie)
      expect(Girb::Railtie.console_block).to be_a(Proc)
    end
  end
end
