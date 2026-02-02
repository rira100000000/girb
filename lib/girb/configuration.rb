# frozen_string_literal: true

module Girb
  class Configuration
    attr_accessor :provider, :debug, :custom_prompt

    def initialize
      @provider = nil
      @debug = ENV["GIRB_DEBUG"] == "1"
      @custom_prompt = nil
    end

    # Get the configured provider, or raise an error if not configured
    def provider!
      return @provider if @provider

      raise ConfigurationError, <<~MSG
        No LLM provider configured.

        Install a provider gem and set GIRB_PROVIDER environment variable:

          gem install girb-ruby_llm
          export GIRB_PROVIDER=girb-ruby_llm

        Or implement your own provider:

          class MyProvider < Girb::Providers::Base
            def chat(messages:, system_prompt:, tools:)
              # Your implementation
            end
          end

          Girb.configure do |c|
            c.provider = MyProvider.new
          end
      MSG
    end
  end
end
