# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/inspect_object"
require_relative "tools/get_source"
require_relative "tools/list_methods"
require_relative "tools/evaluate_code"
require_relative "tools/read_file"
require_relative "tools/find_file"
require_relative "tools/session_history_tool"
require_relative "tools/debug_session_history_tool"
require_relative "tools/environment_tools"
require_relative "tools/continue_analysis"
require_relative "tools/run_irb_debug_command"

module Girb
  module Tools
    # Shared tools available in both IRB and debug modes
    SHARED_TOOLS = [InspectObject, GetSource, ListMethods, EvaluateCode, ReadFile, FindFile, GetCurrentDirectory].freeze

    # IRB-only tools
    IRB_TOOLS = [SessionHistoryTool, ContinueAnalysis, RunIrbDebugCommand].freeze

    # Debug-only tools (RunDebugCommand is registered separately in DebugIntegration)
    DEBUG_TOOLS = [DebugSessionHistoryTool].freeze

    # All core tools (used for backward compatibility)
    CORE_TOOLS = (SHARED_TOOLS + IRB_TOOLS + DEBUG_TOOLS).freeze

    class << self
      def registered_tools
        @registered_tools ||= []
      end

      def register(tool_class)
        registered_tools << tool_class unless registered_tools.include?(tool_class)
      end

      def available_tools
        tools = CORE_TOOLS.dup + registered_tools

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

      def to_gemini_tools
        available_tools.map(&:to_gemini_tool)
      end
    end
  end
end
