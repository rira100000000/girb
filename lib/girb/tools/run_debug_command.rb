# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    class RunDebugCommand < Base
      class << self
        def description
          "Execute a debugger command. Use this tool whenever the user asks to step, continue, set breakpoints, or perform any debugger action. " \
          "For conditional breakpoints, use 'if:' (with colon): e.g., 'break sample.rb:14 if: x == 1'."
        end

        def parameters
          {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The debugger command to execute. Examples: 'n', 's', 'c', 'finish', 'up', 'down', " \
                             "'break sample.rb:14', 'break sample.rb:14 if: x == 1', 'info locals', 'bt'"
              },
              auto_continue: {
                type: "boolean",
                description: "Set to true if you want to be re-invoked after the command executes " \
                             "to see the new state. Use this when you need to check variables or " \
                             "decide the next action after stepping/continuing."
              }
            },
            required: ["command"]
          }
        end

        def available?
          defined?(DEBUGGER__)
        end
      end

      def execute(binding, command:, auto_continue: false)
        Girb::DebugIntegration.add_pending_debug_command(command)
        Girb::DebugIntegration.auto_continue = true if auto_continue
        { success: true, command: command, auto_continue: auto_continue,
          message: auto_continue ?
            "Command '#{command}' will be executed. You will be re-invoked with updated context." :
            "Command '#{command}' will be executed after this response." }
      end
    end
  end
end
