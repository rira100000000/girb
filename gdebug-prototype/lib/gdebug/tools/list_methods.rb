# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class ListMethods < Base
      class << self
        def description
          "List methods available on an object or class. Can filter by pattern."
        end

        def parameters
          {
            type: "object",
            properties: {
              expression: {
                type: "string",
                description: "The variable name or expression to list methods for"
              },
              pattern: {
                type: "string",
                description: "Optional regex pattern to filter method names (e.g., 'valid', 'save')"
              },
              include_inherited: {
                type: "boolean",
                description: "Whether to include inherited methods (default: false)"
              }
            },
            required: ["expression"]
          }
        end
      end

      def execute(binding, expression:, pattern: nil, include_inherited: false)
        obj = binding.eval(expression)

        methods = if obj.is_a?(Class) || obj.is_a?(Module)
                    {
                      instance_methods: obj.instance_methods(!include_inherited),
                      class_methods: obj.methods(!include_inherited)
                    }
                  else
                    {
                      methods: obj.methods(!include_inherited)
                    }
                  end

        if pattern && !pattern.empty?
          regex = Regexp.new(pattern, Regexp::IGNORECASE)
          methods = methods.transform_values do |list|
            list.select { |m| m.to_s.match?(regex) }
          end
        end

        methods.transform_values(&:sort)
      rescue RegexpError => e
        { error: "Invalid pattern: #{e.message}" }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
