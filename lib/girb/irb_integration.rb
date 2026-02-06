# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"
require_relative "session_history"
require_relative "session_persistence"
require_relative "auto_continue"
require_relative "ai_client"

module Girb
  # IRB::Debug.setupをフックして、debug gem初期化後にgirb統合をセットアップ
  module IrbDebugHook
    def setup(irb)
      result = super
      if result && defined?(DEBUGGER__::SESSION)
        # DebugIntegrationを動的に読み込む
        require_relative "debug_integration" unless defined?(Girb::DebugIntegration)
        Girb::DebugIntegration.setup_if_needed

        # Instead of using auto_continue (which causes deadlocks with API calls),
        # inject a qq command to continue the conversation through normal command flow
        if defined?(Girb::AutoContinue) && Girb::AutoContinue.active?
          Girb::AutoContinue.reset!
          # Include original user question so AI remembers the task
          original_question = Girb::IrbIntegration.pending_user_question
          Girb::IrbIntegration.pending_user_question = nil
          if original_question
            continuation = "(auto-continue: デバッグモードに移行しました。最初のデバッグコマンドは既に実行されました。" \
                           "同じコマンドを再度発行しないでください。\n" \
                           "元の指示: 「#{original_question}」\n" \
                           "次のステップに進んでください。例: continueで実行を継続、または結果を確認。)"
          else
            continuation = "(auto-continue: デバッグモードに移行しました。最初のデバッグコマンドは既に実行されました。" \
                           "次のステップに進んでください。)"
          end
          Girb::DebugIntegration.add_pending_debug_command("qq #{continuation}")
        end
      end
      result
    end
  end
  # AI送信フラグ（スレッドローカル）
  def self.ai_send_pending?
    Thread.current[:girb_ai_send_pending]
  end

  def self.ai_send_pending=(value)
    Thread.current[:girb_ai_send_pending] = value
  end

  module IrbIntegration
    @session_started = false
    @exit_hook_installed = false
    @pending_irb_commands = []
    @pending_input_commands = []
    @auto_continue = false

    DEBUG_COMMANDS = %w[next n step s continue c finish break delete backtrace bt info catch debug].freeze

    class << self
      attr_accessor :auto_continue

      def pending_irb_commands
        @pending_irb_commands ||= []
      end

      def add_pending_irb_command(cmd)
        pending_irb_commands << cmd
      end

      def take_pending_irb_commands
        cmds = @pending_irb_commands || []
        @pending_irb_commands = []
        cmds
      end

      # Commands to be injected into IRB's input stream
      def pending_input_commands
        @pending_input_commands ||= []
      end

      def add_pending_input_command(cmd)
        pending_input_commands << cmd
      end

      def take_next_input_command
        @pending_input_commands ||= []
        @pending_input_commands.shift
      end

      def has_pending_input?
        @pending_input_commands && !@pending_input_commands.empty?
      end

      def debug_command?(cmd)
        name = cmd.strip.split(/\s+/, 2).first&.downcase
        DEBUG_COMMANDS.include?(name)
      end

      def auto_continue?
        @auto_continue
      end

      # Store the original user question for continuation after debug mode transition
      attr_accessor :pending_user_question

      def session_started?
        @session_started
      end

      def start_session!
        return if @session_started
        return unless SessionPersistence.enabled?

        SessionPersistence.start_session
        @session_started = true
        setup_exit_hook unless @exit_hook_installed
      end

      def save_session!
        return unless @session_started
        SessionPersistence.save_session
      rescue => e
        # exit時のエラーは静かに無視
        STDERR.puts "[girb] Warning: Failed to save session: #{e.message}" if ENV["GIRB_DEBUG"]
      end
    end

    def self.setup
      # コマンドを登録
      require_relative "../irb/command/qq"

      # 例外キャプチャのインストール
      ExceptionCapture.install

      # Ctrl+Space でAI送信するフックをインストール
      install_eval_hook

      # Ctrl+Space キーバインドをインストール
      install_ai_keybinding

      # readmultiline パッチをインストール（コマンド注入用）
      install_readmultiline_patch

      # セッション永続化が有効なら開始
      start_session! if SessionPersistence.enabled?

      # IRB::Debugをフックして、debug開始時にgirb統合をセットアップ
      install_debug_hook
    end

    def self.install_debug_hook
      return if @debug_hook_installed
      return unless defined?(IRB::Debug)

      IRB::Debug.singleton_class.prepend(Girb::IrbDebugHook)
      @debug_hook_installed = true
    end

    def self.install_readmultiline_patch
      return if @readmultiline_patch_installed

      IRB::Irb.prepend(ReadmultilinePatch)
      @readmultiline_patch_installed = true
    end

    def self.setup_exit_hook
      return if @exit_hook_installed
      @exit_hook_installed = true

      at_exit do
        Girb::IrbIntegration.save_session!
      end
    end

    def self.install_eval_hook
      IRB::Context.prepend(EvalHook)
    end

    def self.install_ai_keybinding
      return unless defined?(Reline)

      Reline::LineEditor.prepend(GirbLineEditorExtension)

      # Ctrl+Space (ASCII 0) にバインド
      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [0], :girb_send_to_ai)
      Reline.core.config.add_default_key_binding_by_keymap(:vi_insert, [0], :girb_send_to_ai)
    end
  end

  module GirbLineEditorExtension
    def girb_send_to_ai(_key)
      Girb.ai_send_pending = true
      finish
    end
  end

  module EvalHook
    def evaluate_expression(code, line_no)
      code = code.to_s

      # Ctrl+Space でAI送信された場合
      if Girb.ai_send_pending?
        Girb.ai_send_pending = false
        question = code.strip
        return if question.empty?

        SessionHistory.record(line_no, question, is_ai_question: true)
        ask_ai(question, line_no)
        return
      end

      # 通常のRubyコード実行時はセッション履歴に記録
      SessionHistory.record(line_no, code)
      super
    end

    private

    def ask_ai(question, line_no)
      # Store the question for continuation after debug mode transition
      Girb::IrbIntegration.pending_user_question = question

      context = ContextBuilder.new(workspace.binding, self).build
      client = AiClient.new
      client.ask(question, context, binding: workspace.binding, line_no: line_no, irb_context: self)

      # Execute any pending IRB commands after AI response
      execute_pending_commands
    rescue StandardError => e
      puts "[girb] Error: #{e.message}"
    end

    def execute_pending_commands
      commands = Girb::IrbIntegration.take_pending_irb_commands
      return if commands.empty?

      commands.each do |cmd|
        if Girb::IrbIntegration.debug_command?(cmd)
          # Debug commands need to be processed at IRB's top level
          # Queue them for injection via readmultiline patch
          puts "[girb] Queuing debug command: #{cmd}"
          Girb::IrbIntegration.add_pending_input_command(cmd)
        else
          # Non-debug commands can be executed directly
          puts "[girb] Executing: #{cmd}"
          begin
            execute_irb_command(cmd)
          rescue StandardError => e
            puts "[girb] Command error: #{e.message}"
          end
        end
      end
    end

    def execute_irb_command(cmd)
      # Parse command and arguments
      parts = cmd.strip.split(/\s+/, 2)
      command_name = parts[0]
      arg = parts[1] || ""

      # Map command names to IRB command classes
      command_class = find_irb_command_class(command_name)

      if command_class
        command_class.execute(self, arg)
      else
        # Fall back to evaluating as Ruby code
        evaluate_expression(cmd, 0)
      end
    end

    def find_irb_command_class(name)
      # Debug-related command mappings
      command_map = {
        "next" => "Next", "n" => "Next",
        "step" => "Step", "s" => "Step",
        "continue" => "Continue", "c" => "Continue",
        "finish" => "Finish",
        "break" => "Break",
        "delete" => "Delete",
        "backtrace" => "Backtrace", "bt" => "Backtrace",
        "info" => "Info",
        "catch" => "Catch",
        "debug" => "Debug"
      }

      class_name = command_map[name.downcase]
      return nil unless class_name

      begin
        IRB::Command.const_get(class_name)
      rescue NameError
        nil
      end
    end
  end

  # Patch to inject pending commands into IRB's input stream
  # This ensures debug commands are processed at the top level of IRB's loop
  module ReadmultilinePatch
    def readmultiline
      # Check for pending commands from girb AI
      if (cmd = Girb::IrbIntegration.take_next_input_command)
        puts "[girb] Injecting command: #{cmd}"
        # Return command with newline so it's processed as complete input
        return cmd.end_with?("\n") ? cmd : "#{cmd}\n"
      end

      result = super

      # After debug command executes and we transition to debug mode,
      # the debug_integration auto_continue mechanism takes over
      result
    end
  end
end
