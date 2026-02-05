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

        unless Girb.configuration&.provider
          puts "[girb] Error: No LLM provider configured."
          puts "[girb] Install a provider gem and configure it:"
          puts "[girb]   gem install girb-ruby_llm"
          puts "[girb]   export GIRB_MODEL=gemini-2.5-flash"
          puts "[girb]   export GEMINI_API_KEY=your-key"
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
        client.ask(question, context, binding: current_binding, line_no: line_no, irb_context: irb_context)
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
