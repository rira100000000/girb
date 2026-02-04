# frozen_string_literal: true

# Girb-specific tools (extending gcore tools)
require_relative "tools/base"
require_relative "tools/session_history_tool"

module Girb
  module Tools
    class << self
      def available_tools
        # Start with gcore's base tools
        tools = Gcore::Tools.all_tools.select(&:available?).dup

        # Add girb-specific tools
        tools << SessionHistoryTool

        # Rails tools are loaded conditionally
        if defined?(Rails)
          require_relative "tools/rails_tools"
          tools << RailsProjectInfo
          tools << RailsModelInfo if defined?(ActiveRecord::Base)
        end

        tools.select { |t| !t.respond_to?(:available?) || t.available? }
      end

      def find_tool(name)
        available_tools.find { |t| t.tool_name == name }
      end

      def to_definitions
        available_tools.map(&:to_tool_definition)
      end

      # Legacy method name for compatibility
      def to_gemini_tools
        to_definitions
      end
    end
  end
end
