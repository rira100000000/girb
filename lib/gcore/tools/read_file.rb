# frozen_string_literal: true

require_relative "base"

module Gcore
  module Tools
    class ReadFile < Base
      MAX_LINES = 100

      class << self
        def description
          "Read contents of a file. Useful for examining source code or configuration files."
        end

        def parameters
          {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Path to the file (relative to project root or absolute)"
              },
              start_line: {
                type: "integer",
                description: "Starting line number (1-indexed, default: 1)"
              },
              end_line: {
                type: "integer",
                description: "Ending line number (default: start_line + 100)"
              }
            },
            required: ["path"]
          }
        end
      end

      def execute(binding, path:, start_line: nil, end_line: nil)
        full_path = resolve_path(path)

        unless File.exist?(full_path)
          return { error: "File not found: #{path}" }
        end

        unless File.file?(full_path)
          return { error: "Not a file: #{path}" }
        end

        lines = File.readlines(full_path)
        start_idx = [(start_line || 1) - 1, 0].max
        end_idx = [(end_line || start_idx + MAX_LINES), lines.length].min - 1

        content_lines = lines[start_idx..end_idx]

        {
          path: full_path,
          start_line: start_idx + 1,
          end_line: end_idx + 1,
          total_lines: lines.length,
          content: format_with_line_numbers(content_lines, start_idx + 1)
        }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def resolve_path(path)
        return path if path.start_with?("/")

        File.expand_path(path, Dir.pwd)
      end

      def format_with_line_numbers(lines, start_num)
        width = (start_num + lines.length).to_s.length
        lines.each_with_index.map do |line, idx|
          "#{(start_num + idx).to_s.rjust(width)}: #{line}"
        end.join
      end
    end
  end
end
