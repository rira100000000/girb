# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/inspect_object"
require_relative "tools/get_source"
require_relative "tools/list_methods"

module Girb
  module Tools
    CORE_TOOLS = [InspectObject, GetSource, ListMethods].freeze

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
