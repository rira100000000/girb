# frozen_string_literal: true

require "debug"
require_relative "debug_context_builder"
require_relative "debug_prompt_builder"

module Girb
  module DebugIntegration
    @ai_triggered = false

    class << self
      attr_accessor :ai_triggered, :auto_continue

      def pending_debug_commands
        @pending_debug_commands ||= []
      end

      def add_pending_debug_command(cmd)
        pending_debug_commands << cmd
      end

      def take_pending_debug_commands
        cmds = @pending_debug_commands || []
        @pending_debug_commands = []
        cmds
      end

      def auto_continue?
        @auto_continue
      end

      def setup
        return unless defined?(DEBUGGER__::SESSION)

        register_ai_command
        register_debug_tools
        setup_keybinding
        puts "[girb] Debug AI assistant loaded. Use 'ai <question>' or Ctrl+Space."
      end

      private

      def register_ai_command
        DEBUGGER__::SESSION.class.prepend(GirbDebugCommands)
      end

      def register_debug_tools
        require_relative "tools/run_debug_command"
        Girb::Tools.register(Girb::Tools::RunDebugCommand)
      end

      def setup_keybinding
        return unless defined?(Reline::LineEditor)

        Reline::LineEditor.prepend(Module.new do
          private def girb_debug_ai_prefix(key)
            Girb::DebugIntegration.ai_triggered = true
            finish
          end
        end)

        Reline.core.config.add_default_key_binding_by_keymap(:emacs, [0], :girb_debug_ai_prefix)
      end
    end

    module GirbDebugCommands
      MAX_AUTO_CONTINUE = 20

      def wait_command
        if Girb::DebugIntegration.auto_continue?
          @girb_auto_continue_count ||= 0
          @girb_auto_continue_count += 1

          if @girb_auto_continue_count > MAX_AUTO_CONTINUE
            @ui.puts "[girb] Auto-continue limit reached (#{MAX_AUTO_CONTINUE})"
            Girb::DebugIntegration.auto_continue = false
            @girb_auto_continue_count = 0
            return :retry
          end

          handle_ai_continuation

          pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if pending_cmds.any?
            pending_cmds.each do |cmd|
              result = process_command(cmd)
              return result unless result == :retry
            end
          else
            Girb::DebugIntegration.auto_continue = false
          end
          return :retry
        else
          @girb_auto_continue_count = 0
        end

        super
      end

      def process_command(line)
        if Girb::DebugIntegration.ai_triggered
          Girb::DebugIntegration.ai_triggered = false
          question = line.strip
          return :retry if question.empty?

          handle_ai_question(question)
          pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if pending_cmds.any?
            pending_cmds.each do |cmd|
              result = super(cmd)
              return result unless result == :retry
            end
          end
          return :retry
        end

        if line.start_with?("ai ")
          question = line.sub(/^ai\s+/, "").strip
          return :retry if question.empty?

          handle_ai_question(question)
          pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if pending_cmds.any?
            pending_cmds.each do |cmd|
              result = super(cmd)
              return result unless result == :retry
            end
          end
          return :retry
        end

        # Auto-detect natural language (non-ASCII input) and route to AI
        if line.match?(/[^\x00-\x7F]/)
          question = line.strip
          return :retry if question.empty?

          handle_ai_question(question)
          pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if pending_cmds.any?
            pending_cmds.each do |cmd|
              result = super(cmd)
              return result unless result == :retry
            end
          end
          return :retry
        end

        super
      end

      private

      def handle_ai_continuation
        current_binding = @tc&.current_frame&.eval_binding
        unless current_binding
          @ui.puts "[girb] Error: No current frame available"
          return
        end

        context = Girb::DebugContextBuilder.new(current_binding).build
        client = Girb::AiClient.new
        continuation = "(auto-continue: The debug command has been executed. Analyze the new state and continue your task.)"
        client.ask(continuation, context, binding: current_binding, debug_mode: true)
      rescue StandardError => e
        @ui.puts "[girb] Auto-continue error: #{e.message}"
        Girb::DebugIntegration.auto_continue = false
      end

      def handle_ai_question(question)
        current_binding = @tc&.current_frame&.eval_binding

        unless current_binding
          puts "[girb] Error: No current frame available"
          return
        end

        context = Girb::DebugContextBuilder.new(current_binding).build
        client = Girb::AiClient.new
        client.ask(question, context, binding: current_binding, debug_mode: true)
      rescue Girb::ConfigurationError => e
        puts "[girb] #{e.message}"
      rescue StandardError => e
        puts "[girb] Error: #{e.message}"
        puts e.backtrace.first(3).join("\n") if Girb.configuration.debug
      end
    end
  end
end
