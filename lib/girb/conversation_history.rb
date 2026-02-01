# frozen_string_literal: true

module Girb
  # AI会話履歴をchat API形式で管理するクラス
  class ConversationHistory
    Message = Struct.new(:role, :content, :tool_calls, :tool_results, keyword_init: true)

    class << self
      def instance
        @instance ||= new
      end

      def reset!
        @instance = new
      end

      def add_user_message(content)
        instance.add_user_message(content)
      end

      def add_assistant_message(content)
        instance.add_assistant_message(content)
      end

      def add_tool_call(tool_name, args, result)
        instance.add_tool_call(tool_name, args, result)
      end

      def to_contents
        instance.to_contents
      end

      def messages
        instance.messages
      end

      def clear!
        instance.clear!
      end

      def summary
        instance.summary
      end

      def to_normalized
        instance.to_normalized
      end
    end

    attr_reader :messages

    def initialize
      @messages = []
      @pending_tool_calls = []
    end

    def add_user_message(content)
      @messages << Message.new(role: "user", content: content)
    end

    def add_assistant_message(content)
      # ツール呼び出しがあった場合は、それも含める
      if @pending_tool_calls.any?
        @messages << Message.new(
          role: "model",
          content: content,
          tool_calls: @pending_tool_calls.dup
        )
        @pending_tool_calls.clear
      else
        @messages << Message.new(role: "model", content: content)
      end
    end

    def add_tool_call(tool_name, args, result)
      @pending_tool_calls << {
        name: tool_name,
        args: args,
        result: result
      }
    end

    def clear!
      @messages.clear
      @pending_tool_calls.clear
    end

    # Gemini API の contents 形式に変換（後方互換性のため残す）
    def to_contents
      @messages.map do |msg|
        {
          role: msg.role,
          parts: [{ text: msg.content }]
        }
      end
    end

    # Provider-agnostic normalized format
    def to_normalized
      result = []

      @messages.each do |msg|
        role = msg.role == "model" ? :assistant : :user
        result << { role: role, content: msg.content }

        # Add tool calls and results if present
        msg.tool_calls&.each do |tc|
          result << { role: :tool_call, name: tc[:name], args: tc[:args] }
          result << { role: :tool_result, name: tc[:name], result: tc[:result] }
        end
      end

      # Add pending tool calls
      @pending_tool_calls.each do |tc|
        result << { role: :tool_call, name: tc[:name], args: tc[:args] }
        result << { role: :tool_result, name: tc[:name], result: tc[:result] }
      end

      result
    end

    # 会話履歴のサマリー（デバッグ用）
    def summary
      @messages.map do |msg|
        role_label = msg.role == "user" ? "USER" : "AI"
        content_preview = msg.content.to_s[0, 50]
        content_preview += "..." if msg.content.to_s.length > 50
        "#{role_label}: #{content_preview}"
      end
    end
  end
end
