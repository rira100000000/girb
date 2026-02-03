# frozen_string_literal: true

require "pathname"

module Girb
  module GirbrcLoader
    class << self
      # Find .girbrc by traversing from start_dir up to root,
      # then fall back to ~/.girbrc
      def find_girbrc(start_dir = Dir.pwd)
        dir = Pathname.new(start_dir).expand_path

        # Traverse up to find .girbrc
        while dir != dir.parent
          candidate = dir.join(".girbrc")
          return candidate if candidate.exist?
          dir = dir.parent
        end

        # Check root directory
        root_candidate = dir.join(".girbrc")
        return root_candidate if root_candidate.exist?

        # Fall back to ~/.girbrc
        home_girbrc = Pathname.new(File.expand_path("~/.girbrc"))
        home_girbrc.exist? ? home_girbrc : nil
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
    end
  end
end
