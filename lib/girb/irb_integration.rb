# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"
require_relative "ai_mode"

module Girb
  module IrbIntegration
    def self.setup
      # コマンドを登録
      require_relative "../irb/command/qq"
      require_relative "../irb/command/qq_chat"

      # 例外キャプチャのインストール
      ExceptionCapture.install

      # AIモード用のフックをインストール
      install_ai_mode_hook
    end

    def self.install_ai_mode_hook
      # IRB::Context#evaluate にフックを追加
      IRB::Context.prepend(AiModeHook)
    end
  end

  module AiModeHook
    def evaluate_expression(code, line_no)
      # AIモードが有効な場合、入力をAIに渡す
      if AiMode.enabled
        code = code.to_s.strip

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
