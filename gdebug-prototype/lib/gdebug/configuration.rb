# frozen_string_literal: true

module Gdebug
  class Configuration
    attr_accessor :provider, :debug, :custom_prompt

    def initialize
      @provider = nil
      @debug = ENV["GDEBUG_DEBUG"] == "1"
      @custom_prompt = nil
    end

    # Get the configured provider, or raise an error if not configured
    def provider!
      return @provider if @provider

      raise ConfigurationError, <<~MSG
        No LLM provider configured.

        Install a provider gem and configure it:

          gem install girb-ruby_llm
          export GDEBUG_PROVIDER=girb-ruby_llm

        Or configure in .gdebugrc:

          require "girb-ruby_llm"

          Gdebug.configure do |c|
            c.provider = Girb::Providers::RubyLlm.new
          end

        Gdebug uses the same providers as girb.
      MSG
    end
  end
end
