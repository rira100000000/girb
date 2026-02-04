# frozen_string_literal: true

module Gcore
  # Manages conversation history for multi-turn AI interactions
  # Thread-safe implementation using thread-local storage
  class ConversationHistory
    class << self
      def messages
        Thread.current[:gcore_conversation_history] ||= []
      end

      def clear
        Thread.current[:gcore_conversation_history] = []
      end

      def add_user_message(content)
        messages << { role: "user", content: content }
      end

      def add_assistant_message(content)
        messages << { role: "assistant", content: content }
      end

      def add_tool_call(tool_name, args, result)
        messages << {
          role: "tool_call",
          content: {
            name: tool_name,
            args: args
          }
        }
        messages << {
          role: "tool_result",
          content: {
            name: tool_name,
            result: result
          }
        }
      end

      # Convert to normalized format for providers
      # @return [Array<Hash>] Messages in provider-agnostic format
      def to_normalized
        messages.map do |msg|
          {
            role: msg[:role],
            content: msg[:content]
          }
        end
      end

      # Get conversation summary for debugging
      def summary
        messages.map do |msg|
          case msg[:role]
          when "user"
            "User: #{msg[:content][0..100]}..."
          when "assistant"
            "Assistant: #{msg[:content][0..100]}..."
          when "tool_call"
            "Tool Call: #{msg[:content][:name]}"
          when "tool_result"
            "Tool Result: #{msg[:content][:name]}"
          end
        end
      end
    end
  end
end
