# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"
require_relative "session_history"
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
    def self.setup
      # コマンドを登録
      require_relative "../irb/command/qq"

      # 例外キャプチャのインストール
      ExceptionCapture.install

      # Ctrl+Space でAI送信するフックをインストール
      install_eval_hook

      # Ctrl+Space キーバインドをインストール
      install_ai_keybinding
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
    rescue StandardError => e
      puts "[girb] Error: #{e.message}"
    end
  end
end
