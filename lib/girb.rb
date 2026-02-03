# frozen_string_literal: true

require_relative "girb/version"
require_relative "girb/configuration"
require_relative "girb/girbrc_loader"
require_relative "girb/providers/base"
require_relative "girb/exception_capture"
require_relative "girb/context_builder"
require_relative "girb/prompt_builder"
require_relative "girb/conversation_history"
require_relative "girb/tools"
require_relative "girb/ai_client"

module Girb
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ApiError < Error; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def setup!
      configure unless configuration
      require_relative "girb/irb_integration"
      IrbIntegration.setup
    end
  end
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
