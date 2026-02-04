# frozen_string_literal: true

# Load all gcore components
require_relative "gcore/version"
require_relative "gcore/configuration"
require_relative "gcore/providers/base"
require_relative "gcore/conversation_history"
require_relative "gcore/context_builder"
require_relative "gcore/prompt_builder"
require_relative "gcore/tools"
require_relative "gcore/ai_client"

module Gcore
  class Error < StandardError; end
  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configuration
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
