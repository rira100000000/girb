# frozen_string_literal: true

module Girb
  module Tools
    # Base class for girb-specific tools
    # Inherits from Gcore::Tools::Base
    class Base < Gcore::Tools::Base
      class << self
        # Legacy method name for compatibility
        def to_gemini_tool
          to_tool_definition
        end
      end
    end
  end
end
