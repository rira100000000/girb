# frozen_string_literal: true

# Load gcore (shared core library)
require_relative "gcore"

# Load girb-specific components
require_relative "girb/version"
require_relative "girb/girbrc_loader"
require_relative "girb/exception_capture"
require_relative "girb/session_history"
require_relative "girb/context_builder"
require_relative "girb/prompt_builder"
require_relative "girb/tools"

module Girb
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    # Delegate configuration to Gcore
    def configuration
      Gcore.configuration
    end

    def configure(&block)
      Gcore.configure(&block)
    end

    def setup!
      configure unless Gcore.configuration
      require_relative "girb/irb_integration"
      IrbIntegration.setup
    end
  end

  # Use Gcore's AI client and conversation history
  AiClient = Gcore::AiClient
  ConversationHistory = Gcore::ConversationHistory
end

# IRB がロードされていたら自動で組み込む
if defined?(IRB)
  Girb.setup!
end

# Rails がロードされていたら Railtie を組み込む
require_relative "girb/railtie" if defined?(Rails::Railtie)

# binding.girb サポート
class Binding
  def girb
    require "irb"
    Girb.setup! unless defined?(IRB::Command::Qq)

    # IRB.start with this binding
    IRB.setup(source_location[0], argv: [])
    workspace = IRB::WorkSpace.new(self)
    irb = IRB::Irb.new(workspace)
    IRB.conf[:MAIN_CONTEXT] = irb.context
    irb.run(IRB.conf)
  end
end
