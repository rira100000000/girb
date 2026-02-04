# frozen_string_literal: true

require "debug"

module Gdebug
  module DebugIntegration
    class << self
      def setup
        return unless defined?(DEBUGGER__::SESSION)

        register_ai_command
        puts "[gdebug] AI assistant loaded. Use 'ai <question>' to ask questions."
      end

      private

      def register_ai_command
        # Extend the Session class to add our command
        DEBUGGER__::SESSION.class.prepend(GdebugCommands)
      end
    end

    module GdebugCommands
      def process_command(line)
        if line.start_with?("ai ")
          question = line.sub(/^ai\s+/, "").strip
          return :retry if question.empty?

          handle_ai_question(question)
          return :retry
        end

        super
      end

      private

      def handle_ai_question(question)
        # Get the current frame's binding
        current_binding = current_frame&.binding

        unless current_binding
          puts "[gdebug] Error: No current frame available"
          return
        end

        context = Gdebug::ContextBuilder.new(current_binding).build
        client = Gdebug::AiClient.new
        client.ask(question, context, binding: current_binding)
      rescue Gdebug::ConfigurationError => e
        puts "[gdebug] #{e.message}"
      rescue StandardError => e
        puts "[gdebug] Error: #{e.message}"
        puts e.backtrace.first(3).join("\n") if Gdebug.configuration.debug
      end
    end
  end
end
