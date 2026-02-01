# frozen_string_literal: true

require "irb/command"

module IRB
  module Command
    class Qq < Base
      category "AI Assistant"
      description "Ask AI a question about your code"

      def execute(question)
        question = question.to_s.strip
        if question.empty?
          puts "[girb] Usage: qq \"your question here\""
          return
        end

        unless Girb.configuration&.gemini_api_key
          puts "[girb] Error: GEMINI_API_KEY not set"
          puts "[girb] Run: export GEMINI_API_KEY=your-key"
          puts "[girb] Or configure in your .irbrc:"
          puts "[girb]   Girb.configure { |c| c.gemini_api_key = 'your-key' }"
          return
        end

        current_binding = irb_context.workspace.binding

        # AI質問を履歴に記録
        line_no = irb_context.line_no rescue 0
        Girb::SessionHistory.record(line_no, question, is_ai_question: true)

        context = Girb::ContextBuilder.new(
          current_binding,
          irb_context
        ).build

        if Girb.configuration.debug
          puts "[girb] Context collected:"
          require "yaml"
          puts context.to_yaml
        end

        client = Girb::AiClient.new
        client.ask(question, context, binding: current_binding, line_no: line_no)
      rescue Girb::Error => e
        puts "[girb] Error: #{e.message}"
      rescue StandardError => e
        puts "[girb] Error: #{e.message}"
        puts e.backtrace.first(5).join("\n") if Girb.configuration&.debug
      end
    end
  end
end

IRB::Command.register(:qq, IRB::Command::Qq)
