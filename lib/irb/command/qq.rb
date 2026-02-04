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

        current_binding = irb_context.workspace.binding

        # AI質問を履歴に記録
        line_no = irb_context.line_no rescue 0
        Girb::SessionHistory.record(line_no, question, is_ai_question: true)

        context = Girb::ContextBuilder.new(
          current_binding,
          irb_context
        ).build

        if Gcore.configuration.debug
          puts "[girb] Context collected:"
          require "yaml"
          puts context.to_yaml
        end

        client = Gcore::AiClient.new(
          prompt_builder_class: Girb::PromptBuilder,
          tools_module: Girb::Tools
        )
        client.ask(question, context, binding: current_binding)
      rescue Gcore::ConfigurationError => e
        puts "[girb] #{e.message}"
      rescue StandardError => e
        puts "[girb] Error: #{e.message}"
        puts e.backtrace.first(5).join("\n") if Gcore.configuration&.debug
      end
    end
  end
end

IRB::Command.register(:qq, IRB::Command::Qq)
