# frozen_string_literal: true

require_relative "base"

module Gcore
  module Tools
    class FindFile < Base
      MAX_RESULTS = 20

      class << self
        def description
          "Find files in the project by name pattern. Supports glob patterns."
        end

        def parameters
          {
            type: "object",
            properties: {
              pattern: {
                type: "string",
                description: "File name pattern (e.g., '*.rb', 'user*.rb', '**/models/*.rb')"
              },
              directory: {
                type: "string",
                description: "Directory to search in (default: current directory)"
              }
            },
            required: ["pattern"]
          }
        end
      end

      def execute(binding, pattern:, directory: nil)
        search_dir = directory || Dir.pwd
        search_dir = File.expand_path(search_dir)

        unless File.directory?(search_dir)
          return { error: "Directory not found: #{search_dir}" }
        end

        glob_pattern = File.join(search_dir, "**", pattern)
        files = Dir.glob(glob_pattern).reject { |f| File.directory?(f) }

        # Filter out common noise
        files = files.reject do |f|
          f.include?("/node_modules/") ||
            f.include?("/.git/") ||
            f.include?("/vendor/bundle/") ||
            f.include?("/tmp/")
        end

        {
          pattern: pattern,
          directory: search_dir,
          count: files.length,
          files: files.first(MAX_RESULTS).map { |f| f.sub("#{search_dir}/", "") },
          truncated: files.length > MAX_RESULTS
        }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end
    end
  end
end
