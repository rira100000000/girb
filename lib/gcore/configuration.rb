# frozen_string_literal: true

module Gcore
  class Configuration
    attr_accessor :provider, :debug, :custom_prompt

    def initialize
      @provider = nil
      @debug = ENV["GCORE_DEBUG"] == "1" || ENV["GIRB_DEBUG"] == "1" || ENV["GDEBUG_DEBUG"] == "1"
      @custom_prompt = nil
    end

    def provider!
      return @provider if @provider

      raise ConfigurationError, <<~MSG
        No AI provider configured.

        Please configure a provider in your config file (.girbrc or .gdebugrc):

          require "girb-ruby_llm"  # or another provider gem

          Gcore.configure do |c|
            c.provider = Gcore::Providers::RubyLlm.new
          end

        Or set environment variables:
          GCORE_PROVIDER=ruby_llm
          GCORE_MODEL=gpt-4
      MSG
    end
  end
end
