# frozen_string_literal: true

require "pathname"

module Girb
  module GirbrcLoader
    class << self
      # Find config file by traversing from start_dir up to root,
      # then fall back to home directory
      def find_config(filename, start_dir = Dir.pwd)
        dir = Pathname.new(start_dir).expand_path

        # Traverse up to find config file
        while dir != dir.parent
          candidate = dir.join(filename)
          return candidate if candidate.exist?
          dir = dir.parent
        end

        # Check root directory
        root_candidate = dir.join(filename)
        return root_candidate if root_candidate.exist?

        # Fall back to home directory
        home_config = Pathname.new(File.expand_path("~/#{filename}"))
        home_config.exist? ? home_config : nil
      end

      # Find .girbrc by traversing from start_dir up to root,
      # then fall back to ~/.girbrc
      def find_girbrc(start_dir = Dir.pwd)
        find_config(".girbrc", start_dir)
      end

      # Find .gdebugrc by traversing from start_dir up to root,
      # then fall back to ~/.gdebugrc
      def find_gdebugrc(start_dir = Dir.pwd)
        find_config(".gdebugrc", start_dir)
      end

      # Load .girbrc if found
      def load_girbrc(start_dir = Dir.pwd)
        girbrc = find_girbrc(start_dir)
        return false unless girbrc

        if Girb.configuration&.debug
          warn "[girb] Loading #{girbrc}"
        end

        load girbrc.to_s
        true
      rescue SyntaxError, LoadError, StandardError => e
        warn "[girb] Error loading #{girbrc}: #{e.message}"
        false
      end

      # Load .gdebugrc if found (for debug gem integration)
      def load_gdebugrc(start_dir = Dir.pwd)
        gdebugrc = find_gdebugrc(start_dir)
        return false unless gdebugrc

        if Girb.configuration&.debug
          warn "[girb] Loading #{gdebugrc}"
        end

        load gdebugrc.to_s
        true
      rescue SyntaxError, LoadError, StandardError => e
        warn "[girb] Error loading #{gdebugrc}: #{e.message}"
        false
      end
    end
  end
end
