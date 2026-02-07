# frozen_string_literal: true

require "spec_helper"
require "girb/tools/rails_tools"

RSpec.describe Girb::Tools::RailsProjectInfo do
  describe ".available?" do
    it "returns falsey when Rails is not defined" do
      expect(described_class.available?).to be_falsey
    end

    context "when Rails is defined" do
      before { stub_const("Rails", Class.new) }

      it "returns truthy" do
        expect(described_class.available?).to be_truthy
      end
    end
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("Rails")
    end
  end

  describe ".parameters" do
    it "has no required parameters" do
      expect(described_class.parameters[:required]).to eq([])
    end
  end

  describe "#execute" do
    let(:tool) { described_class.new }
    let(:test_binding) { binding }

    before do
      rails = Module.new do
        def self.root
          Pathname.new("/app")
        end

        def self.env
          "development"
        end

        def self.version
          "7.1.0"
        end

        def self.application
          nil
        end
      end
      stub_const("Rails", rails)
    end

    it "returns Rails root" do
      result = tool.execute(test_binding)
      expect(result[:root]).to eq("/app")
    end

    it "returns Rails environment" do
      result = tool.execute(test_binding)
      expect(result[:environment]).to eq("development")
    end

    it "returns Ruby version" do
      result = tool.execute(test_binding)
      expect(result[:ruby_version]).to eq(RUBY_VERSION)
    end

    it "returns Rails version" do
      result = tool.execute(test_binding)
      expect(result[:rails_version]).to eq("7.1.0")
    end
  end
end

RSpec.describe Girb::Tools::RailsModelInfo do
  describe ".available?" do
    it "returns falsey when ActiveRecord::Base is not defined" do
      expect(described_class.available?).to be_falsey
    end

    context "when ActiveRecord::Base is defined" do
      before { stub_const("ActiveRecord::Base", Class.new) }

      it "returns truthy" do
        expect(described_class.available?).to be_truthy
      end
    end
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).to include("ActiveRecord")
    end
  end

  describe ".parameters" do
    it "includes model_name as required" do
      params = described_class.parameters
      expect(params[:required]).to include("model_name")
    end
  end

  describe "#execute" do
    let(:tool) { described_class.new }
    let(:test_binding) { binding }

    it "returns error for undefined model" do
      result = tool.execute(test_binding, model_name: "NonExistentModel")
      expect(result[:error]).to include("not found")
    end

    context "with mocked ActiveRecord model" do
      let(:model_class) do
        klass = Class.new
        # Simulate ActiveRecord::Base ancestry
        ar_base = Class.new
        stub_const("ActiveRecord::Base", ar_base)
        # Make klass inherit from ar_base
        allow(klass).to receive(:<).with(ar_base).and_return(true)
        allow(klass).to receive(:table_name).and_return("users")
        allow(klass).to receive(:primary_key).and_return("id")
        allow(klass).to receive(:columns).and_return([])
        allow(klass).to receive(:reflect_on_all_associations).and_return([])
        allow(klass).to receive(:validators).and_return([])
        klass
      end

      it "returns model information" do
        b = binding
        allow(b).to receive(:eval).with("User").and_return(model_class)

        result = tool.execute(b, model_name: "User")
        expect(result[:model]).to eq("User")
        expect(result[:table_name]).to eq("users")
        expect(result[:primary_key]).to eq("id")
      end
    end
  end
end
