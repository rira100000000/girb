# frozen_string_literal: true

require_relative "tools/base"
require_relative "tools/inspect_object"
require_relative "tools/get_source"
require_relative "tools/list_methods"
require_relative "tools/evaluate_code"
require_relative "tools/read_file"
require_relative "tools/find_file"
require_relative "tools/get_current_directory"

module Gdebug
  module Tools
    CORE_TOOLS = [
      InspectObject,
      GetSource,
      ListMethods,
      EvaluateCode,
      ReadFile,
      FindFile,
      GetCurrentDirectory
    ].freeze

    class << self
      def available_tools
        CORE_TOOLS.select { |t| !t.respond_to?(:available?) || t.available? }
      end

      def find_tool(name)
        available_tools.find { |t| t.tool_name == name }
      end
    end
  end
end
