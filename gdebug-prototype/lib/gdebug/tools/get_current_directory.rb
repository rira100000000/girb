# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class GetCurrentDirectory < Base
      class << self
        def description
          "Get the current working directory."
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
