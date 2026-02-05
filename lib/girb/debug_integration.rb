# frozen_string_literal: true

require "debug"
require_relative "debug_context_builder"
require_relative "debug_prompt_builder"
require_relative "debug_session_history"

module Girb
  module DebugIntegration
    @ai_triggered = false
    @interrupted = false

    class << self
      attr_accessor :ai_triggered, :auto_continue, :interrupted

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

      def interrupted?
        @interrupted
      end

      def interrupt!
        @interrupted = true
      end

      def clear_interrupt!
        @interrupted = false
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

          # Set up interrupt handler on first iteration
          if @girb_auto_continue_count == 1
            setup_interrupt_handler
          end

          # Check for interrupt (Ctrl+C)
          if Girb::DebugIntegration.interrupted?
            Girb::DebugIntegration.auto_continue = false
            Girb::DebugIntegration.clear_interrupt!
            @girb_auto_continue_count = 0
            restore_interrupt_handler
            handle_ai_interrupted
            return :retry
          end

          if @girb_auto_continue_count > MAX_AUTO_CONTINUE
            Girb::DebugIntegration.auto_continue = false
            @girb_auto_continue_count = 0
            restore_interrupt_handler
            handle_ai_turn_limit_reached
            return :retry
          end

          begin
            handle_ai_continuation
          rescue Exception => e
            if e.is_a?(Interrupt) || e.class.name.include?("Interrupt") || e.class.name.include?("Abort")
              Girb::DebugIntegration.auto_continue = false
              Girb::DebugIntegration.clear_interrupt!
              @girb_auto_continue_count = 0
              restore_interrupt_handler
              handle_ai_interrupted
              return :retry
            else
              raise
            end
          end

          # Check for interrupt after API call (Ctrl+C during request)
          if Girb::DebugIntegration.interrupted?
            Girb::DebugIntegration.auto_continue = false
            Girb::DebugIntegration.clear_interrupt!
            @girb_auto_continue_count = 0
            restore_interrupt_handler
            handle_ai_interrupted
            return :retry
          end

          pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if pending_cmds.any?
            pending_cmds.each do |cmd|
              result = process_command(cmd)
              return result unless result == :retry
            end
          else
            Girb::DebugIntegration.auto_continue = false
            restore_interrupt_handler
          end
          return :retry
        else
          @girb_auto_continue_count = 0
          Girb::DebugIntegration.clear_interrupt!
        end

        super
      end

      def process_command(line)
        if Girb::DebugIntegration.ai_triggered
          Girb::DebugIntegration.ai_triggered = false
          question = line.strip
          return :retry if question.empty?

          Girb::DebugSessionHistory.record_ai_question(question)
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

          Girb::DebugSessionHistory.record_ai_question(question)
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

          Girb::DebugSessionHistory.record_ai_question(question)
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

        # Record regular debugger commands
        Girb::DebugSessionHistory.record_command(line)
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

      def handle_ai_turn_limit_reached
        current_binding = @tc&.current_frame&.eval_binding
        return unless current_binding

        context = Girb::DebugContextBuilder.new(current_binding).build
        client = Girb::AiClient.new
        limit_message = "(System: Auto-continue turn limit (#{MAX_AUTO_CONTINUE}) reached. " \
                        "Summarize your progress so far and tell the user what was accomplished. " \
                        "If the task is not complete, explain what remains and instruct the user " \
                        "to continue with a follow-up request.)"
        client.ask(limit_message, context, binding: current_binding, debug_mode: true)
      rescue StandardError => e
        puts "[girb] Auto-continue limit reached (#{MAX_AUTO_CONTINUE})"
        puts "[girb] Error summarizing: #{e.message}" if Girb.configuration.debug
      end

      def handle_ai_interrupted
        puts "\n[girb] Interrupted by user (Ctrl+C)"
        current_binding = @tc&.current_frame&.eval_binding
        return unless current_binding

        context = Girb::DebugContextBuilder.new(current_binding).build
        client = Girb::AiClient.new
        interrupt_message = "(System: User interrupted with Ctrl+C. " \
                            "Briefly summarize your progress so far. " \
                            "Tell the user where you stopped and how to continue if needed.)"
        client.ask(interrupt_message, context, binding: current_binding, debug_mode: true)
      rescue StandardError => e
        puts "[girb] Error summarizing: #{e.message}" if Girb.configuration.debug
      end

      def setup_interrupt_handler
        @original_int_handler = trap("INT") do
          Girb::DebugIntegration.interrupt!
          # Raise Interrupt to break out of blocking IO operations
          Thread.main.raise(Interrupt)
        end
      end

      def restore_interrupt_handler
        if @original_int_handler
          trap("INT", @original_int_handler)
          @original_int_handler = nil
        else
          trap("INT", "DEFAULT")
        end
      end
    end
  end
end
