# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/evaluate_code"
require_relative "tools/inspect_object"
require_relative "tools/get_source"
require_relative "tools/list_methods"
require_relative "tools/read_file"
require_relative "tools/find_file"
require_relative "tools/get_current_directory"

module Gcore
  module Tools
    class << self
      # All registered tool classes
      def all_tools
        @all_tools ||= [
          EvaluateCode,
          InspectObject,
          GetSource,
          ListMethods,
          ReadFile,
          FindFile,
          GetCurrentDirectory
        ]
      end

      # Tools that are currently available
      def available_tools
        all_tools.select(&:available?)
      end

      # Find a tool by name
      def find_tool(name)
        available_tools.find { |t| t.tool_name == name }
      end

      # Register a custom tool
      def register(tool_class)
        @all_tools ||= []
        @all_tools << tool_class unless @all_tools.include?(tool_class)
      end

      # Get tool definitions for AI
      def to_definitions
        available_tools.map(&:to_tool_definition)
      end
    end
  end
end

# Aliases for girb/gdebug compatibility
module Girb
  Tools = Gcore::Tools
end

module Gdebug
  Tools = Gcore::Tools
end
