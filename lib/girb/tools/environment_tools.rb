# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    # General tool for getting current directory - always available
    class GetCurrentDirectory < Base
      class << self
        def description
          "Get the current working directory (pwd). Use this when user asks about current directory or project location."
        end

        def parameters
          {
            type: "object",
            properties: {},
            required: []
          }
        end
      end

      def execute(binding)
        {
          current_directory: Dir.pwd,
          home_directory: Dir.home
        }
      end
    end
  end
end
