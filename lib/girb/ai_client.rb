# frozen_string_literal: true

require "gemini"

module Girb
  class AiClient
    MAX_TOOL_ITERATIONS = 10

    def initialize
      @client = Gemini::Client.new(Girb.configuration.gemini_api_key)
    end

    def ask(question, context, binding: nil)
      @current_binding = binding

      prompt = PromptBuilder.new(question, context).build
      tools = build_tools

      process_with_tools(prompt, tools)
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

    def process_with_tools(prompt, tools)
      iterations = 0
      current_prompt = prompt
      contents = nil  # 継続用

      loop do
        iterations += 1
        if iterations > MAX_TOOL_ITERATIONS
          puts "\n[girb] Tool iteration limit reached"
          break
        end

        response = if contents
                     call_api_with_contents(contents, tools)
                   else
                     call_api(current_prompt, tools)
                   end
        break unless response

        # Function callがあるかチェック
        if response.function_calls&.any?
          function_call = response.function_calls.first
          tool_name = function_call["name"]
          tool_args = function_call["args"] || {}

          puts "[girb] Tool: #{tool_name}(#{tool_args.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')})"

          result = execute_tool(tool_name, tool_args)

          # エラーがあれば表示
          if result.is_a?(Hash) && result[:error]
            puts "[girb] Tool error: #{result[:error]}"
          end

          # 継続用のcontentsを構築
          original_contents = [{ role: "user", parts: [{ text: current_prompt }] }]
          contents = Gemini::FunctionCallingHelper.build_continuation(
            original_contents: original_contents,
            model_response: response,
            function_responses: [{ name: tool_name, response: result }]
          )
        else
          # テキストレスポンスを表示
          if response.text
            puts response.text
          elsif response.error
            puts "[girb] API Error: #{response.error}"
          end
          break
        end
      end
    end

    def call_api(prompt, tools)
      if Girb.configuration.debug
        puts "[girb] Calling Gemini API..."
      end

      @client.generate_content(
        prompt,
        model: Girb.configuration.model,
        tools: tools
      )
    rescue Faraday::BadRequestError => e
      puts "[girb] API Error: #{e.message}"
      nil
    rescue StandardError => e
      puts "[girb] Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n") if Girb.configuration.debug
      nil
    end

    def call_api_with_contents(contents, tools)
      if Girb.configuration.debug
        puts "[girb] Calling Gemini API (continuation)..."
      end

      @client.chat(parameters: {
        model: Girb.configuration.model,
        contents: contents,
        tools: tools.to_h[:function_declarations] ? [{ function_declarations: tools.to_h[:function_declarations] }] : nil
      }.compact)
    rescue Faraday::BadRequestError => e
      puts "[girb] API Error: #{e.message}"
      nil
    rescue StandardError => e
      puts "[girb] Error: #{e.class} - #{e.message}"
      puts e.backtrace.first(3).join("\n") if Girb.configuration.debug
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
  end
end
