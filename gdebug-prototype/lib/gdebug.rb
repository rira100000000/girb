# frozen_string_literal: true

require_relative "gdebug/version"
require_relative "gdebug/configuration"
require_relative "gdebug/providers/base"
require_relative "gdebug/conversation_history"
require_relative "gdebug/context_builder"
require_relative "gdebug/prompt_builder"
require_relative "gdebug/tools"
require_relative "gdebug/ai_client"

module Gdebug
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    # Setup gdebug with debug gem
    def setup!
      load_config_file
      require_relative "gdebug/debug_integration"
      DebugIntegration.setup
    end

    private

    def load_config_file
      config_file = find_config_file
      return unless config_file

      if configuration.debug
        puts "[gdebug] Loading config: #{config_file}"
      end

      load config_file
    rescue StandardError => e
      warn "[gdebug] Error loading config file: #{e.message}"
    end

    def find_config_file
      # Check current directory and parents
      dir = Dir.pwd
      while dir != "/"
        config = File.join(dir, ".gdebugrc")
        return config if File.exist?(config)
        dir = File.dirname(dir)
      end

      # Check home directory
      home_config = File.join(Dir.home, ".gdebugrc")
      return home_config if File.exist?(home_config)

      nil
    end
  end
end

# Auto-setup when required with debug
if defined?(DEBUGGER__)
  Gdebug.setup!
end
