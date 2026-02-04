# frozen_string_literal: true

module Gcore
  module Tools
    # Base class for AI tools
    #
    # Tools allow the AI to interact with the Ruby runtime and codebase.
    # Implement this class to add new capabilities.
    #
    # Example:
    #   class MyTool < Gcore::Tools::Base
    #     class << self
    #       def description
    #         "Does something useful"
    #       end
    #
    #       def parameters
    #         {
    #           type: "object",
    #           properties: {
    #             input: { type: "string", description: "Input value" }
    #           },
    #           required: ["input"]
    #         }
    #       end
    #     end
    #
    #     def execute(binding, input:)
    #       { result: "processed #{input}" }
    #     end
    #   end
    #
    class Base
      class << self
        # Tool name derived from class name (e.g., EvaluateCode -> evaluate_code)
        def tool_name
          name.split("::").last.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/^_/, "")
        end

        # Tool description for the AI
        def description
          raise NotImplementedError, "#{name} must implement .description"
        end

        # JSON Schema for tool parameters
        def parameters
          raise NotImplementedError, "#{name} must implement .parameters"
        end

        # Convert to tool definition format
        def to_tool_definition
          {
            name: tool_name,
            description: description,
            parameters: parameters
          }
        end

        # Override to conditionally enable tools
        def available?
          true
        end
      end

      # Execute the tool with given binding and parameters
      # @param binding [Binding] Current execution context
      # @param params [Hash] Tool parameters
      # @return [Hash] Result hash (may include :error key on failure)
      def execute(binding, **params)
        raise NotImplementedError, "#{self.class.name} must implement #execute"
      end

      protected

      def safe_inspect(obj, max_length: 1000)
        if defined?(ActiveRecord::Base) && obj.is_a?(ActiveRecord::Base)
          return inspect_active_record(obj)
        end

        result = obj.inspect
        result.length > max_length ? "#{result[0, max_length]}..." : result
      rescue StandardError => e
        "#<#{obj.class} (inspect failed: #{e.message})>"
      end

      def inspect_active_record(obj)
        {
          class: obj.class.name,
          id: obj.try(:id),
          attributes: obj.attributes,
          new_record: obj.new_record?,
          changed: obj.changed?,
          errors: obj.errors.full_messages
        }.to_s
      end
    end
  end
end
