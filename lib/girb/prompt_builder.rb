# frozen_string_literal: true

module Girb
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      あなたはRuby開発者をIRBでのデバッグ作業を支援するAIアシスタントです。

      ## 役割
      - 現在の実行コンテキスト（変数、オブジェクト状態、例外）を分析する
      - 質問に対して具体的で実用的な回答を提供する
      - 必要に応じてツールを使用して追加情報を取得する

      ## 回答のガイドライン
      - 日本語で回答してください
      - 簡潔で実用的な回答を心がけてください
      - コード例を含める場合は、現在のコンテキストに合わせてください
      - エラーの説明では、原因と解決策を明確に示してください

      ## 利用可能なツール
      ツールを使用して、変数の詳細な検査、ソースコードの取得、メソッド一覧の確認ができます。
      必要に応じて積極的に活用してください。
    PROMPT

    def initialize(question, context)
      @question = question
      @context = context
    end

    def build
      <<~PROMPT
        #{SYSTEM_PROMPT}

        ## 現在のコンテキスト

        ### 実行位置
        #{format_source_location}

        ### ローカル変数
        #{format_locals}

        ### self の情報
        #{format_self_info}

        ### 直前の評価結果
        #{@context[:last_value] || "(なし)"}

        ### 直前の例外
        #{format_exception}

        ### 直近のコマンド履歴
        #{format_history}

        ## 質問
        #{@question}
      PROMPT
    end

    private

    def format_source_location
      loc = @context[:source_location]
      return "(不明)" unless loc

      "ファイル: #{loc[:file]}\n行番号: #{loc[:line]}"
    end

    def format_locals
      return "(なし)" if @context[:local_variables].empty?

      @context[:local_variables].map do |name, value|
        "- #{name}: #{value}"
      end.join("\n")
    end

    def format_self_info
      info = @context[:self_info]
      return "(不明)" unless info

      lines = ["クラス: #{info[:class]}"]
      lines << "inspect: #{info[:inspect]}"
      if info[:methods]&.any?
        lines << "定義されたメソッド: #{info[:methods].join(', ')}"
      end
      lines.join("\n")
    end

    def format_exception
      exc = @context[:last_exception]
      return "(なし)" unless exc

      <<~EXC
        クラス: #{exc[:class]}
        メッセージ: #{exc[:message]}
        発生時刻: #{exc[:time]}
        バックトレース:
        #{exc[:backtrace]&.map { |l| "  #{l}" }&.join("\n")}
      EXC
    end

    def format_history
      history = @context[:history]
      return "(なし)" if history.nil? || history.empty?

      history.map.with_index(1) { |cmd, i| "#{i}. #{cmd}" }.join("\n")
    end
  end
end
