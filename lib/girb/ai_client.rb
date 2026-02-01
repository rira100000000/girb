# frozen_string_literal: true

require "gemini"
require_relative "conversation_history"

module Girb
  class AiClient
    MAX_TOOL_ITERATIONS = 10

    def initialize
      @client = Gemini::Client.new(Girb.configuration.gemini_api_key)
    end

    def ask(question, context, binding: nil, line_no: nil)
      @current_binding = binding
      @current_line_no = line_no
      @reasoning_log = []

      prompt_builder = PromptBuilder.new(question, context)
      @system_prompt = prompt_builder.system_prompt
      user_message = prompt_builder.user_message

      # 会話履歴にユーザーメッセージを追加
      ConversationHistory.add_user_message(user_message)

      tools = build_tools

      process_with_tools(tools)
    end

    private

    def build_tools
      tools = Gemini::ToolDefinition.new

      Tools.available_tools.each do |tool_class|
        params = tool_class.parameters
        properties = params[:properties] || {}
        required = params[:required] || []

        tools.add_function(
          tool_class.tool_name.to_sym,
          description: tool_class.description
        ) do
          properties.each do |prop_name, prop_def|
            type = prop_def[:type]&.to_sym || :string
            desc = prop_def[:description] || ""
            is_required = required.include?(prop_name.to_s) || required.include?(prop_name)

            property prop_name, type: type, description: desc, required: is_required
          end
        end
      end

      tools
    end

    def process_with_tools(tools)
      iterations = 0
      tool_continuation = nil  # ツール呼び出し継続用
      accumulated_text = []    # function_callと一緒に返ってきたテキストを蓄積

      loop do
        iterations += 1
        if iterations > MAX_TOOL_ITERATIONS
          puts "\n[girb] Tool iteration limit reached"
          break
        end

        response = if tool_continuation
                     call_api_with_tool_continuation(tool_continuation, tools)
                   else
                     call_chat_api(tools)
                   end

        unless response
          puts "[girb] Error: No response from API"
          break
        end

        if Girb.configuration.debug
          puts "[girb] function_calls: #{response.function_calls&.inspect}"
          puts "[girb] text: #{response.text&.slice(0, 100).inspect}"
          puts "[girb] error: #{response.error.inspect}" if response.respond_to?(:error)
        end

        # Function callがあるかチェック
        if response.function_calls&.any?
          # function_callと一緒にテキストが返ってきた場合は蓄積
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          function_call = response.function_calls.first
          tool_name = function_call["name"]
          tool_args = function_call["args"] || {}

          puts "[girb] Tool: #{tool_name}(#{tool_args.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')})"

          result = execute_tool(tool_name, tool_args)

          # 思考の過程を記録
          @reasoning_log << {
            tool: tool_name,
            args: tool_args,
            result: result
          }

          # 会話履歴にツール呼び出しを記録
          ConversationHistory.add_tool_call(tool_name, tool_args, result)

          # エラーがあれば表示
          if result.is_a?(Hash) && result[:error]
            puts "[girb] Tool error: #{result[:error]}"
          end

          # ツール継続用のcontentsを構築
          tool_continuation = build_tool_continuation(response, tool_name, result)
        else
          # テキストレスポンスを表示（蓄積されたテキストも含める）
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          if accumulated_text.any?
            full_text = accumulated_text.join("\n")
            puts full_text
            # 会話履歴にアシスタントの回答を追加
            ConversationHistory.add_assistant_message(full_text)
            # セッション履歴にも記録
            record_ai_response(full_text)
          elsif response.error
            puts "[girb] API Error: #{response.error}"
          else
            # 予期しないレスポンス形式
            puts "[girb] Warning: Empty or unexpected response"
            if Girb.configuration.debug
              puts "[girb] Response: #{response.inspect}"
              puts "[girb] Raw response: #{response.raw_data.inspect}" if response.respond_to?(:raw_data)
            end
          end
          break
        end
      end
    end

    def build_tool_continuation(response, tool_name, result)
      # 会話履歴 + ツール呼び出し + ツール結果
      contents = ConversationHistory.to_contents

      # モデルのツール呼び出しを追加
      contents << {
        role: "model",
        parts: response.parts
      }

      # ツール結果を追加
      contents << {
        role: "user",
        parts: [{
          function_response: {
            name: tool_name,
            response: result
          }
        }]
      }

      contents
    end

    def call_chat_api(tools)
      if Girb.configuration.debug
        puts "[girb] Calling Gemini Chat API..."
        puts "[girb] Conversation history: #{ConversationHistory.summary.join(' | ')}"
      end

      contents = ConversationHistory.to_contents
      tools_param = tools.to_h[:function_declarations] ? [{ function_declarations: tools.to_h[:function_declarations] }] : nil

      response = @client.chat(parameters: {
        model: Girb.configuration.model,
        system_instruction: { parts: [{ text: @system_prompt }] },
        contents: contents,
        tools: tools_param
      }.compact)

      if Girb.configuration.debug
        puts "[girb] Response class: #{response.class}"
      end

      response
    rescue Faraday::BadRequestError => e
      puts "[girb] API Error (BadRequest): #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    rescue StandardError => e
      puts "[girb] Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    end

    def call_api_with_tool_continuation(contents, tools)
      if Girb.configuration.debug
        puts "[girb] Calling Gemini API (tool continuation)..."
      end

      tools_param = tools.to_h[:function_declarations] ? [{ function_declarations: tools.to_h[:function_declarations] }] : nil

      response = @client.chat(parameters: {
        model: Girb.configuration.model,
        system_instruction: { parts: [{ text: @system_prompt }] },
        contents: contents,
        tools: tools_param
      }.compact)

      if Girb.configuration.debug && response
        puts "[girb] Response class: #{response.class}"
      end

      response
    rescue Faraday::BadRequestError => e
      puts "[girb] API Error (BadRequest): #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    rescue StandardError => e
      puts "[girb] Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
      nil
    end

    def execute_tool(tool_name, args)
      tool_class = Tools.find_tool(tool_name)

      unless tool_class
        return { error: "Unknown tool: #{tool_name}" }
      end

      tool = tool_class.new
      symbolized_args = args.transform_keys(&:to_sym)

      if @current_binding
        tool.execute(@current_binding, **symbolized_args)
      else
        { error: "No binding available for tool execution" }
      end
    rescue StandardError => e
      { error: "Tool execution failed: #{e.class} - #{e.message}" }
    end

    def record_ai_response(response)
      return unless @current_line_no

      reasoning = @reasoning_log.empty? ? nil : format_reasoning
      SessionHistory.record_ai_response(@current_line_no, response, reasoning)
    end

    def format_reasoning
      @reasoning_log.map do |log|
        args_str = log[:args].map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
        result_str = log[:result].inspect
        result_str = result_str[0, 500] + "..." if result_str.length > 500
        "Tool: #{log[:tool]}(#{args_str})\nResult: #{result_str}"
      end.join("\n\n")
    end
  end
end
