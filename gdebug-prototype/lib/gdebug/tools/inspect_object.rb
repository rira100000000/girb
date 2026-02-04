# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class InspectObject < Base
      class << self
        def description
          "Inspect a variable or expression in the current debug context. " \
          "Returns detailed information about the object including its class, value, and instance variables."
        end

        def parameters
          {
            type: "object",
            properties: {
              expression: {
                type: "string",
                description: "The variable name or Ruby expression to inspect (e.g., 'user', 'user.errors', '@items.first')"
              }
            },
            required: ["expression"]
          }
        end
      end

      def execute(binding, expression:)
        result = binding.eval(expression)
        {
          expression: expression,
          class: result.class.name,
          value: safe_inspect(result),
          instance_variables: extract_instance_variables(result),
          methods_count: result.methods.count
        }
      rescue SyntaxError => e
        { error: "Syntax error: #{e.message}" }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def extract_instance_variables(obj)
        obj.instance_variables.to_h do |var|
          value = obj.instance_variable_get(var)
          [var, safe_inspect(value, max_length: 200)]
        end
      rescue StandardError
        {}
      end
    end
  end
end
