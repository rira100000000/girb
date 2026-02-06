# frozen_string_literal: true

require_relative "base"
require_relative "../debug_session_history"
require_relative "../conversation_history"
require_relative "../session_persistence"

module Girb
  module Tools
    class DebugSessionHistoryTool < Base
      class << self
        def name
          "get_session_history"
        end

        def description
          "Get session history including AI conversations from previous sessions (if persisted) and current session commands. " \
          "Use this to recall past conversations and debug commands."
        end

        def parameters
          {
            type: "object",
            properties: {
              action: {
                type: "string",
                enum: %w[full_history list_ai_conversations],
                description: "Action: full_history (all commands and AI conversations), list_ai_conversations (AI Q&A only)"
              },
              count: {
                type: "integer",
                description: "Number of recent entries to retrieve (default: 20)"
              }
            },
            required: ["action"]
          }
        end

        def available?
          defined?(DEBUGGER__)
        end
      end

      def execute(_binding, action:, count: 20)
        case action
        when "full_history"
          get_full_history(count)
        when "list_ai_conversations"
          list_ai_conversations(count)
        else
          { error: "Unknown action: #{action}. Use 'full_history' or 'list_ai_conversations'." }
        end
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def get_full_history(count)
        result = {}

        # 永続化されたセッションからの会話履歴
        persisted = get_persisted_conversations
        if persisted.any?
          result[:persisted_conversations] = persisted
        end

        # 現在のセッションのデバッグ履歴
        history = DebugSessionHistory.format_history(count)
        if history && !history.empty?
          result[:current_session_history] = history
        end

        if result.empty?
          { message: "No history available" }
        else
          result
        end
      end

      def list_ai_conversations(count = 20)
        all_conversations = []

        # 永続化されたセッションからの会話
        persisted = get_persisted_conversations
        all_conversations.concat(persisted)

        # 現在のセッションの会話
        current = DebugSessionHistory.ai_conversations.map do |c|
          {
            question: c.content,
            response: c.response || "(pending)",
            source: "current_session"
          }
        end
        all_conversations.concat(current)

        if all_conversations.any?
          # 最新のcount件に制限
          limited = all_conversations.last(count)
          {
            total_count: all_conversations.size,
            showing: limited.size,
            conversations: limited.map do |c|
              response = c[:response] || ""
              response_preview = response.length > 200 ? "#{response[0, 200]}..." : response
              {
                question: c[:question],
                response_preview: response_preview,
                source: c[:source] || "persisted"
              }
            end
          }
        else
          { message: "No AI conversations in session history" }
        end
      end

      def get_persisted_conversations
        conversations = []
        ConversationHistory.messages.each do |msg|
          if msg.role == "user"
            conversations << { question: msg.content, source: "persisted" }
          elsif msg.role == "model" && conversations.last && !conversations.last[:response]
            conversations.last[:response] = msg.content
          end
        end
        conversations
      end
    end
  end
end
