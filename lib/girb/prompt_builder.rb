# frozen_string_literal: true

module Girb
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      あなたはRuby開発者のIRBセッションに組み込まれたAIアシスタントです。

      ## 重要: IRBセッションの文脈を理解する
      ユーザーはIRBで対話的にコードを実行しながら、その流れの中で質問をしています。
      「セッション履歴」には、ユーザーがこれまでに実行したコードと過去のAI会話が時系列で記録されています。
      質問は常にこの履歴の文脈で解釈してください。

      例えば履歴が:
        1: a = 1
        2: b = 2
        3: [USER] c = 3以降も実行すると、zはいくつになる？
      の場合、ユーザーは「a=1, b=2, c=3...」というパターンを続けたときのzの値を聞いています（答え: z=26）。

      ## 役割
      - セッション履歴を分析し、ユーザーが何をしようとしているか理解する
      - 現在の実行コンテキスト（変数、オブジェクト状態、例外）を活用する
      - 質問に対して具体的で実用的な回答を提供する
      - 必要に応じてツールを使用してコードを実行・検証する

      ## 回答のガイドライン
      - 日本語で回答してください
      - 簡潔で実用的な回答を心がけてください
      - パターンや意図を読み取り、仮定的な質問にも対応してください
      - コード例を含める場合は、現在のコンテキストに合わせてください

      ## 利用可能なツール
      ツールを使用して、変数の詳細な検査、ソースコードの取得、コードの実行ができます。
      特にevaluate_codeツールは、仮説の検証や計算に積極的に活用してください。
    PROMPT

    def initialize(question, context)
      @question = question
      @context = context
    end

    # 従来の単一プロンプト形式（後方互換性のため）
    def build
      <<~PROMPT
        #{SYSTEM_PROMPT}

        #{build_context_section}

        ## 質問
        #{@question}
      PROMPT
    end

    # システムプロンプト（会話全体で共通）
    def system_prompt
      SYSTEM_PROMPT
    end

    # ユーザーメッセージ（コンテキスト + 質問）
    def user_message
      <<~MSG
        ## 現在のIRBコンテキスト
        #{build_context_section}

        ## 質問
        #{@question}
      MSG
    end

    private

    def build_context_section
      <<~CONTEXT
        ### セッション履歴（これまでのIRB入力）
        以下はユーザーがこれまでに実行したコードです。質問はこの流れの中で行われています。
        #{format_session_history}

        ### 現在のローカル変数
        #{format_locals}

        ### 直前の評価結果
        #{@context[:last_value] || "(なし)"}

        ### 直前の例外
        #{format_exception}

        ### IRBで定義されたメソッド
        #{format_method_definitions}
      CONTEXT
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

    def format_session_history
      history = @context[:session_history]
      return "(なし)" if history.nil? || history.empty?

      history.join("\n")
    end

    def format_method_definitions
      methods = @context[:method_definitions]
      return "(なし)" if methods.nil? || methods.empty?

      methods.join("\n")
    end
  end
end
