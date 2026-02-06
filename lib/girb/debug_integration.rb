# frozen_string_literal: true

require "debug"
require_relative "debug_context_builder"
require_relative "debug_prompt_builder"
require_relative "debug_session_history"
require_relative "session_persistence"

module Girb
  module DebugIntegration
    # Define at module level so it's accessible as Girb::DebugIntegration::GIRB_DIR
    # Points to lib directory, not gem root, so user's files aren't filtered
    GIRB_DIR = File.expand_path('..', __dir__)

    @ai_triggered = false
    @interrupted = false
    @session_started = false

    class << self
      attr_accessor :ai_triggered, :auto_continue, :interrupted, :api_thread

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

      def session_started?
        @session_started
      end

      def start_session!
        return if @session_started

        SessionPersistence.start_session
        @session_started = true
        setup_exit_hook
      end

      def save_session!
        SessionPersistence.save_session if @session_started
      end

      def setup
        return unless defined?(DEBUGGER__::SESSION)
        return if @setup_done

        register_ai_command
        register_debug_tools
        setup_keybinding
        patch_debugger_frame_filter
        @setup_done = true
        puts "[girb] Debug AI assistant loaded. Use 'qq <question>' or Ctrl+Space."
      end

      def patch_debugger_frame_filter
        return unless defined?(DEBUGGER__)
        return if @frame_filter_patched

        # girbのフレームもdebuggerのスタックトレースから除外
        if DEBUGGER__.respond_to?(:capture_frames)
          original_method = DEBUGGER__.method(:capture_frames)
          DEBUGGER__.define_singleton_method(:capture_frames) do |*args|
            frames = original_method.call(*args)
            frames.reject! do |frame|
              frame.realpath&.start_with?(Girb::DebugIntegration::GIRB_DIR)
            end
            frames
          end
        end

        @frame_filter_patched = true
      end

      # IRBからdebugモードに入った時に呼ばれる
      def setup_if_needed
        return if @setup_done
        setup
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

      def setup_exit_hook
        at_exit do
          Girb::DebugIntegration.save_session!
        end
      end
    end

    module GirbDebugCommands
      MAX_AUTO_CONTINUE = 20

      def wait_command
        # First, check for any pending commands (e.g., injected qq commands from IRB mode transition)
        # Process these before entering auto_continue or waiting for user input
        pending_cmds = Girb::DebugIntegration.take_pending_debug_commands
        if pending_cmds.any?
          pending_cmds.each do |cmd|
            result = process_command(cmd)
            return result unless result == :retry
          end
          return :retry
        end

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

          more_cmds = Girb::DebugIntegration.take_pending_debug_commands
          if more_cmds.any?
            more_cmds.each do |cmd|
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

        if line.start_with?("qq ")
          question = line.sub(/^qq\s+/, "").strip
          return :retry if question.empty?

          # セッション管理コマンド
          if question.start_with?("session ")
            handle_session_command(question.sub(/^session\s+/, ""))
            return :retry
          end

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
        # Disable Ruby's Timeout during API call to avoid deadlock with debug gem's threading
        with_timeout_disabled do
          client.ask(continuation, context, binding: current_binding, debug_mode: true)
        end
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

        # 初回のAI質問時にセッションを開始
        Girb::DebugIntegration.start_session!

        context = Girb::DebugContextBuilder.new(current_binding).build
        client = Girb::AiClient.new
        # Disable Ruby's Timeout during API call to avoid deadlock with debug gem's threading
        with_timeout_disabled do
          client.ask(question, context, binding: current_binding, debug_mode: true)
        end
      rescue Girb::ConfigurationError => e
        puts "[girb] #{e.message}"
      rescue StandardError => e
        puts "[girb] Error: #{e.message}"
        puts e.backtrace.first(3).join("\n") if Girb.configuration.debug
      end

      # Temporarily disable Ruby's Timeout module to avoid deadlock with debug gem
      # The underlying socket has its own timeout, so this is safe
      def with_timeout_disabled
        return yield unless defined?(Timeout)

        original_timeout = Timeout.method(:timeout)
        Timeout.define_singleton_method(:timeout) do |_sec, _klass = nil, _message = nil, &block|
          block.call
        end
        yield
      ensure
        Timeout.define_singleton_method(:timeout, original_timeout) if original_timeout
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
        with_timeout_disabled do
          client.ask(limit_message, context, binding: current_binding, debug_mode: true)
        end
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
        with_timeout_disabled do
          client.ask(interrupt_message, context, binding: current_binding, debug_mode: true)
        end
      rescue StandardError => e
        puts "[girb] Error summarizing: #{e.message}" if Girb.configuration.debug
      end

      def setup_interrupt_handler
        Girb::DebugIntegration.api_thread = Thread.current
        @original_int_handler = trap("INT") do
          Girb::DebugIntegration.interrupt!
          # Raise Interrupt to break out of blocking IO operations
          thread = Girb::DebugIntegration.api_thread
          thread&.raise(Interrupt) if thread&.alive?
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

      def handle_session_command(cmd)
        case cmd.strip
        when "clear"
          Girb::SessionPersistence.clear_session
        when "list"
          sessions = Girb::SessionPersistence.list_sessions
          if sessions.empty?
            puts "[girb] No saved sessions"
          else
            puts "[girb] Saved sessions:"
            sessions.each do |s|
              puts "  - #{s[:id]} (#{s[:message_count]} messages, saved: #{s[:saved_at]})"
            end
          end
        when "status"
          if Girb::SessionPersistence.current_session_id
            puts "[girb] Current session: #{Girb::SessionPersistence.current_session_id}"
          elsif Girb.debug_session
            puts "[girb] Session configured: #{Girb.debug_session} (not started)"
          else
            puts "[girb] No session configured (use Girb.debug_session = 'name' to enable)"
          end
        else
          puts "[girb] Unknown session command: #{cmd}"
          puts "[girb] Available: clear, list, status"
        end
      end
    end
  end
end
