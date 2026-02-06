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
          puts "[girb]        qq session clear  - Clear current session"
          puts "[girb]        qq session list   - List saved sessions"
          return
        end

        # セッション管理コマンド
        if question.start_with?("session ")
          handle_session_command(question.sub(/^session\s+/, ""))
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

        # セッションが有効なら開始
        Girb::IrbIntegration.start_session! if Girb::SessionPersistence.enabled?

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

      private

      def handle_session_command(cmd)
        case cmd.strip
        when "clear"
          Girb::SessionPersistence.clear_session
        when "list"
          sessions = Girb::SessionPersistence.list_sessions
          if sessions.empty?
            puts "[girb] No saved sessions"
          else
            puts "[girb] Saved sessions:"
            sessions.each do |s|
              puts "  - #{s[:id]} (#{s[:message_count]} messages, saved: #{s[:saved_at]})"
            end
          end
        when "status"
          if Girb::SessionPersistence.current_session_id
            puts "[girb] Current session: #{Girb::SessionPersistence.current_session_id}"
          elsif Girb.debug_session
            puts "[girb] Session configured: #{Girb.debug_session} (not started)"
          else
            puts "[girb] No session configured (use Girb.debug_session = 'name' to enable)"
          end
        else
          puts "[girb] Unknown session command: #{cmd}"
          puts "[girb] Available: clear, list, status"
        end
      end
    end
  end
end

IRB::Command.register(:qq, IRB::Command::Qq)
