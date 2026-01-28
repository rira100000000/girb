# frozen_string_literal: true

module Girb
  module AiMode
    @enabled = false
    @original_prompt = nil

    class << self
      attr_reader :enabled

      def toggle(irb_context)
        if @enabled
          disable(irb_context)
        else
          enable(irb_context)
        end
      end

      def enable(irb_context)
        return if @enabled

        @enabled = true
        @original_prompt = irb_context.prompt_mode

        # AIモード用のプロンプトを設定
        IRB.conf[:PROMPT][:GIRB_AI] = {
          PROMPT_I: "\e[1;35mai>\e[0m ",      # 紫色で "ai>"
          PROMPT_S: "\e[1;35mai*\e[0m ",
          PROMPT_C: "\e[1;35mai*\e[0m ",
          RETURN: ""  # 戻り値は表示しない（AIの応答のみ）
        }
        irb_context.prompt_mode = :GIRB_AI

        puts "\e[1;35m[girb] AIモード ON\e[0m - 自然言語で質問できます (終了: qq-chat)"
      end

      def disable(irb_context)
        return unless @enabled

        @enabled = false
        irb_context.prompt_mode = @original_prompt || :DEFAULT

        puts "\e[0m[girb] AIモード OFF\e[0m"
      end

      def ask_ai(question, irb_context)
        context = ContextBuilder.new(
          irb_context.workspace.binding,
          irb_context
        ).build

        client = AiClient.new
        client.ask(question, context, binding: irb_context.workspace.binding)
      rescue StandardError => e
        puts "[girb] Error: #{e.message}"
      end
    end
  end
end
