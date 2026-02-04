# frozen_string_literal: true

require_relative "conversation_history"
require_relative "providers/base"

module Gdebug
  class AiClient
    MAX_TOOL_ITERATIONS = 10

    def initialize
      @provider = Gdebug.configuration.provider!
    end

    def ask(question, context, binding: nil)
      @current_binding = binding
      @reasoning_log = []

      prompt_builder = PromptBuilder.new(question, context)
      @system_prompt = prompt_builder.system_prompt
      user_message = prompt_builder.user_message

      ConversationHistory.add_user_message(user_message)

      tools = build_tools
      process_with_tools(tools)
    end

    private

    def build_tools
      Tools.available_tools.map do |tool_class|
        {
          name: tool_class.tool_name,
          description: tool_class.description,
          parameters: tool_class.parameters
        }
      end
    end

    def process_with_tools(tools)
      iterations = 0
      accumulated_text = []

      loop do
        iterations += 1
        if iterations > MAX_TOOL_ITERATIONS
          puts "\n[gdebug] Tool iteration limit reached"
          break
        end

        messages = ConversationHistory.to_normalized
        response = @provider.chat(
          messages: messages,
          system_prompt: @system_prompt,
          tools: tools,
          binding: @current_binding
        )

        if Gdebug.configuration.debug
          puts "[gdebug] function_calls: #{response.function_calls.inspect}"
          puts "[gdebug] text: #{response.text&.slice(0, 100).inspect}"
          puts "[gdebug] error: #{response.error.inspect}" if response.error
        end

        unless response
          puts "[gdebug] Error: No response from API"
          break
        end

        if response.error && !response.function_call?
          puts "[gdebug] API Error: #{response.error}"
          break
        end

        if response.function_call?
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          function_call = response.function_calls.first
          tool_name = function_call[:name]
          tool_args = function_call[:args] || {}

          if Gdebug.configuration.debug
            puts "[gdebug] Tool: #{tool_name}(#{tool_args.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')})"
          end

          result = execute_tool(tool_name, tool_args)

          @reasoning_log << {
            tool: tool_name,
            args: tool_args,
            result: result
          }

          ConversationHistory.add_tool_call(tool_name, tool_args, result)

          if Gdebug.configuration.debug && result.is_a?(Hash) && result[:error]
            puts "[gdebug] Tool error: #{result[:error]}"
          end
        else
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          if accumulated_text.any?
            full_text = accumulated_text.join("\n")
            puts full_text
            ConversationHistory.add_assistant_message(full_text)
          elsif Gdebug.configuration.debug
            puts "[gdebug] Warning: Empty or unexpected response"
          end
          break
        end
      end
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
