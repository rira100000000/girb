# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"
require_relative "session_history"
require_relative "session_persistence"
require_relative "ai_client"

module Girb
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

    class << self
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

      # セッション永続化が有効なら開始
      start_session! if SessionPersistence.enabled?
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
        puts "[girb] Executing: #{cmd}"
        begin
          # Execute the command through IRB's normal evaluation
          # Debug commands like 'next', 'step' will be handled by IRB's built-in debug integration
          evaluate_expression(cmd, 0)
        rescue StandardError => e
          puts "[girb] Command error: #{e.message}"
        end
      end
    end
  end
end
