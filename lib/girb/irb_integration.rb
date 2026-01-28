# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"
require_relative "ai_mode"

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
      require_relative "../irb/command/qq_chat"

      # 例外キャプチャのインストール
      ExceptionCapture.install

      # AIモード用のフックをインストール
      install_ai_mode_hook

      # Ctrl+Space でAI送信するキーバインドをインストール
      install_ai_keybinding
    end

    def self.install_ai_mode_hook
      # IRB::Context#evaluate にフックを追加
      IRB::Context.prepend(AiModeHook)
    end

    def self.install_ai_keybinding
      return unless defined?(Reline)

      # Reline::LineEditor にカスタムメソッドを追加
      Reline::LineEditor.prepend(GirbLineEditorExtension)

      # Ctrl+Space (ASCII 0) にバインド
      Reline.core.config.add_default_key_binding_by_keymap(:emacs, [0], :girb_send_to_ai)
      Reline.core.config.add_default_key_binding_by_keymap(:vi_insert, [0], :girb_send_to_ai)
    end
  end

  module GirbLineEditorExtension
    def girb_send_to_ai(_key)
      # AI送信フラグを立てて確定
      Girb.ai_send_pending = true
      finish
    end
  end

  module AiModeHook
    def evaluate_expression(code, line_no)
      code = code.to_s

      # Ctrl+Space でAI送信された場合（フラグ検出）
      if Girb.ai_send_pending?
        Girb.ai_send_pending = false
        question = code.strip
        return if question.empty?

        AiMode.ask_ai(question, self)
        return
      end

      # AIモードが有効な場合、入力をAIに渡す
      if AiMode.enabled
        code = code.strip

        # 空行はスキップ
        return if code.empty?

        # qq-chat でトグル（終了）
        if code == "qq-chat"
          AiMode.disable(self)
          return
        end

        # > で始まる場合はRubyコードとして実行
        if code.start_with?(">")
          return super(code[1..].strip, line_no)
        end

        # AIに質問
        AiMode.ask_ai(code, self)
        return
      end

      super
    end
  end
end
