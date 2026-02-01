# frozen_string_literal: true

module Girb
  class Configuration
    attr_accessor :provider, :debug, :custom_prompt

    # Legacy accessors for backward compatibility
    attr_writer :gemini_api_key, :model

    def initialize
      @provider = nil
      @debug = ENV["GIRB_DEBUG"] == "1"
      @custom_prompt = nil

      # Legacy settings (used by girb-gemini if provider not set)
      @gemini_api_key = ENV["GEMINI_API_KEY"]
      @model = "gemini-2.5-flash"
    end

    # Legacy accessor - returns API key for backward compatibility
    def gemini_api_key
      @gemini_api_key
    end

    # Legacy accessor - returns model for backward compatibility
    def model
      @model
    end

    # Get the configured provider, or raise an error if not configured
    def provider!
      return @provider if @provider

      # Try to auto-configure Gemini if legacy settings are present
      if @gemini_api_key && defined?(Girb::Providers::Gemini)
        @provider = Girb::Providers::Gemini.new(
          api_key: @gemini_api_key,
          model: @model
        )
        return @provider
      end

      raise ConfigurationError, <<~MSG
        No LLM provider configured.

        Install a provider gem and configure it:

          # Using girb-gemini
          gem 'girb-gemini'

          Girb.configure do |c|
            c.provider = Girb::Providers::Gemini.new(
              api_key: ENV['GEMINI_API_KEY']
            )
          end

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
