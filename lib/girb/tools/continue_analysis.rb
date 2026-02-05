# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    class ContinueAnalysis < Base
      class << self
        def description
          "Request to be re-invoked with a refreshed context (updated local variables, " \
          "instance variables, last value, etc.). Use this after executing code that " \
          "changes state, when you need to see the full updated picture before deciding " \
          "your next action."
        end

        def parameters
          {
            type: "object",
            properties: {
              reason: {
                type: "string",
                description: "Brief description of why you need a context refresh and what you plan to check next."
              }
            },
            required: ["reason"]
          }
        end

        def available?
          # In debug mode, use run_debug_command with auto_continue instead
          !defined?(DEBUGGER__)
        end
      end

      def execute(binding, reason:)
        Girb::AutoContinue.request!
        {
          success: true,
          message: "You will be re-invoked with updated context after this response.",
          reason: reason
        }
      end
    end
  end
end
