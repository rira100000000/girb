# frozen_string_literal: true

require "stringio"
require_relative "base"

module Girb
  module Tools
    class EvaluateCode < Base
      class << self
        def description
          "Execute arbitrary Ruby code in the current context and return the result. " \
          "Use this to call methods, create objects, test conditions, or perform any Ruby operation."
        end

        def parameters
          {
            type: "object",
            properties: {
              code: {
                type: "string",
                description: "Ruby code to execute (e.g., 'user.valid?', 'Order.where(status: :pending).count', 'arr.map { |x| x * 2 }')"
              }
            },
            required: ["code"]
          }
        end
      end

      def execute(binding, code:)
        captured_output = StringIO.new
        original_stdout = $stdout
        $stdout = captured_output

        begin
          result = binding.eval(code)
        ensure
          $stdout = original_stdout
        end

        stdout_str = captured_output.string
        # Also print captured output to the real console for user visibility
        print stdout_str unless stdout_str.empty?

        response = {
          code: code,
          result: safe_inspect(result),
          result_class: result.class.name,
          success: true
        }
        response[:stdout] = stdout_str unless stdout_str.empty?
        response
      rescue SyntaxError => e
        $stdout = original_stdout if $stdout != original_stdout
        { code: code, error: "Syntax error: #{e.message}", success: false }
      rescue StandardError => e
        $stdout = original_stdout if $stdout != original_stdout
        stdout_str = captured_output&.string
        response = { code: code, error: "#{e.class}: #{e.message}", backtrace: e.backtrace&.first(5), success: false }
        response[:stdout] = stdout_str if stdout_str && !stdout_str.empty?
        response
      end
    end
  end
end
