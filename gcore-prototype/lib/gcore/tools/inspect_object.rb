# frozen_string_literal: true

require_relative "base"

module Gcore
  module Tools
    class InspectObject < Base
      class << self
        def description
          "Inspect an object in detail. Shows class, instance variables, and available methods."
        end

        def parameters
          {
            type: "object",
            properties: {
              expression: {
                type: "string",
                description: "The variable name or expression to inspect"
              }
            },
            required: ["expression"]
          }
        end
      end

      def execute(binding, expression:)
        obj = binding.eval(expression)

        {
          class: obj.class.name,
          inspect: safe_inspect(obj),
          instance_variables: extract_instance_variables(obj),
          methods: obj.methods(false).sort.first(30),
          ancestors: obj.class.ancestors.first(10).map(&:to_s)
        }
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
