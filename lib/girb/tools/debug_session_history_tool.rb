# frozen_string_literal: true

require_relative "base"
require_relative "../debug_session_history"

module Girb
  module Tools
    class DebugSessionHistoryTool < Base
      class << self
        def name
          "get_session_history"
        end

        def description
          "Get debug session history including debugger commands and AI conversations. " \
          "Note: Recent history is also shown in the 'Session History' section of the context."
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
          list_ai_conversations
        else
          { error: "Unknown action: #{action}. Use 'full_history' or 'list_ai_conversations'." }
        end
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def get_full_history(count)
        history = DebugSessionHistory.format_history(count)
        if history && !history.empty?
          { history: history }
        else
          { message: "No history in this debug session" }
        end
      end

      def list_ai_conversations
        conversations = DebugSessionHistory.ai_conversations
        if conversations.any?
          {
            count: conversations.size,
            conversations: conversations.map do |c|
              response_preview = if c.response
                                   c.response.length > 200 ? "#{c.response[0, 200]}..." : c.response
                                 else
                                   "(pending)"
                                 end
              {
                question: c.content,
                response_preview: response_preview
              }
            end
          }
        else
          { message: "No AI conversations in this debug session" }
        end
      end
    end
  end
end
