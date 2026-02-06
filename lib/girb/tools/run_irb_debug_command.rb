# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    class RunIrbDebugCommand < Base
      class << self
        def name
          "run_debug_command"
        end

        def description
          "Execute a debug command in IRB. IRB integrates with debug gem, allowing step-by-step debugging. " \
          "Use this when the user asks to step through code, set breakpoints, or navigate execution."
        end

        def parameters
          {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The debug command to execute. Examples: 'next', 'step', 'continue', 'finish', " \
                             "'break sample.rb:14', 'break sample.rb:14 if: x == 1', 'info', 'backtrace'"
              },
              auto_continue: {
                type: "boolean",
                description: "Set to true to be re-invoked after the command executes to see the new state."
              }
            },
            required: ["command"]
          }
        end

        def available?
          # Available in IRB mode (not debug mode)
          defined?(IRB) && !defined?(DEBUGGER__)
        end
      end

      def execute(binding, command:, auto_continue: false)
        Girb::IrbIntegration.add_pending_irb_command(command)
        Girb::AutoContinue.request! if auto_continue

        {
          success: true,
          command: command,
          auto_continue: auto_continue,
          message: auto_continue ?
            "Command '#{command}' will be executed. You will be re-invoked with updated context." :
            "Command '#{command}' will be executed after this response."
        }
      end
    end
  end
end
