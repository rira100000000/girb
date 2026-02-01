# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/inspect_object"
require_relative "tools/get_source"
require_relative "tools/list_methods"
require_relative "tools/evaluate_code"
require_relative "tools/read_file"
require_relative "tools/find_file"
require_relative "tools/session_history_tool"

module Girb
  module Tools
    CORE_TOOLS = [InspectObject, GetSource, ListMethods, EvaluateCode, ReadFile, FindFile, SessionHistoryTool].freeze

    class << self
      def available_tools
        tools = CORE_TOOLS.dup

        # Rails tools are loaded conditionally
        if defined?(ActiveRecord::Base)
          require_relative "tools/rails_tools"
          tools << RailsModelInfo
        end

        tools.select { |t| !t.respond_to?(:available?) || t.available? }
      end

      def find_tool(name)
        available_tools.find { |t| t.tool_name == name }
      end

      def to_gemini_tools
        available_tools.map(&:to_gemini_tool)
      end
    end
  end
end
