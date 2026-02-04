# frozen_string_literal: true

require_relative "base"

module Gcore
  module Tools
    class EvaluateCode < Base
      class << self
        def description
          "Evaluate Ruby code in the current context. " \
          "Use this to test hypotheses, inspect values, or run debugging commands."
        end

        def parameters
          {
            type: "object",
            properties: {
              code: {
                type: "string",
                description: "The Ruby code to evaluate"
              }
            },
            required: ["code"]
          }
        end
      end

      def execute(binding, code:)
        result = binding.eval(code)
        {
          result: safe_inspect(result),
          result_class: result.class.name
        }
      rescue SyntaxError => e
        { error: "SyntaxError: #{e.message}" }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}", backtrace: e.backtrace&.first(5) }
      end
    end
  end
end
