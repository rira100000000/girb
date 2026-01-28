# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    class FindFile < Base
      MAX_RESULTS = 20

      class << self
        def description
          "Find files in the application by name pattern. " \
          "Useful for locating models, controllers, views, or any files. " \
          "Supports glob patterns like '*.rb' or '**/*user*.rb'."
        end

        def parameters
          {
            type: "object",
            properties: {
              pattern: {
                type: "string",
                description: "File name pattern (glob). Examples: 'user.rb', '**/user*.rb', 'app/models/*.rb'"
              },
              directory: {
                type: "string",
                description: "Directory to search in (optional, defaults to app root)"
              }
            },
            required: ["pattern"]
          }
        end
      end

      def execute(binding, pattern:, directory: nil)
        base_dir = resolve_base_directory(directory)

        unless Dir.exist?(base_dir)
          return { error: "Directory not found: #{base_dir}" }
        end

        # パターンにディレクトリが含まれていなければ再帰検索
        search_pattern = if pattern.include?("/") || pattern.include?("**/")
                           File.join(base_dir, pattern)
                         else
                           File.join(base_dir, "**", pattern)
                         end

        files = Dir.glob(search_pattern).reject { |f| File.directory?(f) }

        # 結果を制限
        truncated = files.length > MAX_RESULTS
        files = files.first(MAX_RESULTS)

        # 相対パスに変換
        relative_files = files.map { |f| f.sub("#{base_dir}/", "") }

        {
          pattern: pattern,
          base_directory: base_dir,
          files: relative_files,
          count: relative_files.length,
          truncated: truncated
        }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def resolve_base_directory(directory)
        if directory
          return directory if directory.start_with?("/")

          base = app_root
          File.join(base, directory)
        else
          app_root
        end
      end

      def app_root
        if defined?(Rails) && Rails.respond_to?(:root) && Rails.root
          Rails.root.to_s
        elsif defined?(Bundler) && Bundler.respond_to?(:root) && Bundler.root
          Bundler.root.to_s
        else
          Dir.pwd
        end
      end
    end
  end
end
