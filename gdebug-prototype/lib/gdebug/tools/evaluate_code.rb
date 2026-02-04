# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class EvaluateCode < Base
      class << self
        def description
          "Execute arbitrary Ruby code in the current debug context and return the result. " \
          "Use this to inspect values, call methods, or test conditions."
        end

        def parameters
          {
            type: "object",
            properties: {
              code: {
                type: "string",
                description: "Ruby code to execute (e.g., 'user.valid?', 'Order.count', 'arr.map { |x| x * 2 }')"
              }
            },
            required: ["code"]
          }
        end
      end

      def execute(binding, code:)
        result = binding.eval(code)
        {
          code: code,
          result: safe_inspect(result),
          result_class: result.class.name,
          success: true
        }
      rescue SyntaxError => e
        { code: code, error: "Syntax error: #{e.message}", success: false }
      rescue StandardError => e
        { code: code, error: "#{e.class}: #{e.message}", backtrace: e.backtrace&.first(5), success: false }
      end
    end
  end
end
