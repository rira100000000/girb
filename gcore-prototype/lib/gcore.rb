# frozen_string_literal: true

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
      yield(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

# Aliases for backward compatibility with girb/gdebug
module Girb
  def self.configuration
    Gcore.configuration
  end

  def self.configure(&block)
    Gcore.configure(&block)
  end

  module Providers
    Base = Gcore::Providers::Base
  end
end

module Gdebug
  def self.configuration
    Gcore.configuration
  end

  def self.configure(&block)
    Gcore.configure(&block)
  end

  module Providers
    Base = Gcore::Providers::Base
  end
end
