# frozen_string_literal: true

require_relative "base"
require_relative "../session_history"

module Girb
  module Tools
    class SessionHistoryTool < Base
      class << self
        def name
          "get_session_history"
        end

        def description
          "Get IRB session history. Can retrieve specific lines, line ranges, method definitions, AI conversation details, or full history."
        end

        def available?
          # Only available in IRB mode, not in debug mode
          !defined?(DEBUGGER__)
        end

        def parameters
          {
            type: "object",
            properties: {
              action: {
                type: "string",
                enum: %w[get_line get_range get_method list_methods full_history list_ai_conversations get_ai_detail],
                description: "Action to perform: get_line (single line), get_range (line range), get_method (method source), list_methods (list defined methods), full_history (all history), list_ai_conversations (list AI Q&A), get_ai_detail (get AI response with reasoning)"
              },
              line: {
                type: "integer",
                description: "Line number for get_line action"
              },
              start_line: {
                type: "integer",
                description: "Start line for get_range action"
              },
              end_line: {
                type: "integer",
                description: "End line for get_range action"
              },
              method_name: {
                type: "string",
                description: "Method name for get_method action"
              }
            },
            required: ["action"]
          }
        end
      end

      def execute(_binding, action:, line: nil, start_line: nil, end_line: nil, method_name: nil)
        case action
        when "get_line"
          get_single_line(line)
        when "get_range"
          get_line_range(start_line, end_line)
        when "get_method"
          get_method_source(method_name)
        when "list_methods"
          list_defined_methods
        when "full_history"
          get_full_history
        when "list_ai_conversations"
          list_ai_conversations
        when "get_ai_detail"
          get_ai_detail(line)
        else
          { error: "Unknown action: #{action}" }
        end
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def get_single_line(line)
        return { error: "line parameter is required" } unless line

        entry = SessionHistory.find_by_line(line)
        if entry
          {
            line: entry.line_no,
            code: entry.code,
            method_definition: entry.method_definition&.name
          }
        else
          { error: "Line #{line} not found in session history" }
        end
      end

      def get_line_range(start_line, end_line)
        return { error: "start_line and end_line parameters are required" } unless start_line && end_line

        entries = SessionHistory.find_by_line_range(start_line, end_line)
        if entries.any?
          {
            range: "#{start_line}-#{end_line}",
            entries: entries.map { |e| { line: e.line_no, code: e.code } }
          }
        else
          { error: "No entries found in range #{start_line}-#{end_line}" }
        end
      end

      def get_method_source(method_name)
        return { error: "method_name parameter is required" } unless method_name

        method_def = SessionHistory.find_method(method_name)
        if method_def
          {
            method_name: method_def.name,
            start_line: method_def.start_line,
            end_line: method_def.end_line,
            source: method_def.code
          }
        else
          { error: "Method '#{method_name}' not found in session history" }
        end
      end

      def list_defined_methods
        methods = SessionHistory.method_definitions
        if methods.any?
          {
            count: methods.size,
            methods: methods.map do |m|
              {
                name: m.name,
                lines: "#{m.start_line}-#{m.end_line}"
              }
            end
          }
        else
          { message: "No methods defined in this session" }
        end
      end

      def get_full_history
        history = SessionHistory.all_with_line_numbers
        if history.any?
          {
            count: history.size,
            history: history
          }
        else
          { message: "No history in this session" }
        end
      end

      def list_ai_conversations
        conversations = SessionHistory.ai_conversations
        if conversations.any?
          {
            count: conversations.size,
            conversations: conversations.map do |c|
              {
                line: c[:line_no],
                question: c[:question],
                response_preview: c[:response][0, 200] + (c[:response].length > 200 ? "..." : "")
              }
            end
          }
        else
          { message: "No AI conversations in this session" }
        end
      end

      def get_ai_detail(line)
        return { error: "line parameter is required" } unless line

        detail = SessionHistory.get_ai_detail(line)
        if detail
          {
            line: detail[:line_no],
            question: detail[:question],
            response: detail[:response],
            reasoning: detail[:reasoning]
          }
        else
          { error: "No AI conversation found at line #{line}" }
        end
      end
    end
  end
end
