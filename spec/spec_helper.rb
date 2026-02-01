# frozen_string_literal: true

require "bundler/setup"
require "webmock/rspec"

# Define Girb module with configuration before loading components
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
  end
end

# Stub IRB module to prevent auto-loading
module IRB; end

require "girb/version"
require "girb/configuration"
require "girb/exception_capture"
require "girb/context_builder"
require "girb/prompt_builder"
require "girb/tools"

# binding.girb support for debugging in tests
class Binding
  def girb
    # Disable WebMock to allow real API calls during debugging
    WebMock.allow_net_connect! if defined?(WebMock)

    require "irb"
    require "girb"
    Girb.setup!

    IRB.setup(source_location[0], argv: [])
    workspace = IRB::WorkSpace.new(self)
    irb = IRB::Irb.new(workspace)
    IRB.conf[:MAIN_CONTEXT] = irb.context
    irb.run(IRB.conf)
  ensure
    # Re-enable WebMock after debugging
    WebMock.disable_net_connect! if defined?(WebMock)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do
    Girb.configuration = nil
    Girb::ExceptionCapture.clear
  end
end
