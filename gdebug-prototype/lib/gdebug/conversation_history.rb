# frozen_string_literal: true

module Gdebug
  # AI conversation history manager
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

      def to_normalized
        instance.to_normalized
      end

      def messages
        instance.messages
      end

      def clear!
        instance.clear!
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

    def to_normalized
      result = []

      @messages.each do |msg|
        role = msg.role == "model" ? :assistant : :user
        result << { role: role, content: msg.content }

        msg.tool_calls&.each do |tc|
          result << { role: :tool_call, name: tc[:name], args: tc[:args] }
          result << { role: :tool_result, name: tc[:name], result: tc[:result] }
        end
      end

      @pending_tool_calls.each do |tc|
        result << { role: :tool_call, name: tc[:name], args: tc[:args] }
        result << { role: :tool_result, name: tc[:name], result: tc[:result] }
      end

      result
    end
  end
end
