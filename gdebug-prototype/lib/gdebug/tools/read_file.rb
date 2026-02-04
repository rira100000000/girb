# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class ReadFile < Base
      MAX_FILE_SIZE = 100_000
      MAX_LINES = 500

      class << self
        def description
          "Read source code from a file. Useful for viewing code around the current debug location."
        end

        def parameters
          {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "File path (relative or absolute)"
              },
              start_line: {
                type: "integer",
                description: "Start line number (1-indexed, optional)"
              },
              end_line: {
                type: "integer",
                description: "End line number (1-indexed, optional)"
              }
            },
            required: ["path"]
          }
        end
      end

      def execute(binding, path:, start_line: nil, end_line: nil)
        full_path = resolve_path(path)

        unless File.exist?(full_path)
          return { error: "File not found: #{path}", searched_path: full_path }
        end

        unless File.readable?(full_path)
          return { error: "File not readable: #{path}" }
        end

        if File.size(full_path) > MAX_FILE_SIZE
          return { error: "File too large (max #{MAX_FILE_SIZE / 1000}KB): #{path}" }
        end

        read_file_content(full_path, path, start_line, end_line)
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def resolve_path(path)
        return path if path.start_with?("/")

        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          return File.join(Rails.root, path)
        end

        if defined?(Bundler) && Bundler.respond_to?(:root) && Bundler.root
          return File.join(Bundler.root, path)
        end

        File.expand_path(path, Dir.pwd)
      end

      def read_file_content(full_path, original_path, start_line, end_line)
        lines = File.readlines(full_path)
        total_lines = lines.length

        if start_line || end_line
          start_idx = [(start_line || 1) - 1, 0].max
          end_idx = [(end_line || total_lines) - 1, total_lines - 1].min
          end_idx = [end_idx, start_idx + MAX_LINES - 1].min

          selected_lines = lines[start_idx..end_idx]
          content = selected_lines.map.with_index(start_idx + 1) { |line, num| "#{num}: #{line}" }.join

          {
            path: original_path,
            full_path: full_path,
            lines: "#{start_idx + 1}-#{end_idx + 1}",
            total_lines: total_lines,
            content: content
          }
        else
          if lines.length > MAX_LINES
            content = lines.first(MAX_LINES).map.with_index(1) { |line, num| "#{num}: #{line}" }.join
            {
              path: original_path,
              full_path: full_path,
              lines: "1-#{MAX_LINES}",
              total_lines: total_lines,
              truncated: true,
              content: content
            }
          else
            content = lines.map.with_index(1) { |line, num| "#{num}: #{line}" }.join
            {
              path: original_path,
              full_path: full_path,
              total_lines: total_lines,
              content: content
            }
          end
        end
      end
    end
  end
end
