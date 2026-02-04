# frozen_string_literal: true

module Gcore
  # Main client for AI interactions
  # Handles tool execution loop and conversation management
  class AiClient
    MAX_TOOL_ITERATIONS = 10

    attr_reader :prompt_builder_class

    def initialize(prompt_builder_class: PromptBuilder)
      @provider = Gcore.configuration.provider!
      @prompt_builder_class = prompt_builder_class
    end

    def ask(question, context, binding: nil, on_response: nil)
      @current_binding = binding
      @on_response = on_response

      prompt_builder = @prompt_builder_class.new(question, context)
      @system_prompt = prompt_builder.system_prompt
      user_message = prompt_builder.user_message

      ConversationHistory.add_user_message(user_message)

      tools = Tools.to_definitions
      process_with_tools(tools)
    end

    private

    def process_with_tools(tools)
      iterations = 0
      accumulated_text = []

      loop do
        iterations += 1
        if iterations > MAX_TOOL_ITERATIONS
          output "[gcore] Tool iteration limit reached"
          break
        end

        messages = ConversationHistory.to_normalized
        response = @provider.chat(
          messages: messages,
          system_prompt: @system_prompt,
          tools: tools,
          binding: @current_binding
        )

        debug_log("function_calls: #{response.function_calls.inspect}")
        debug_log("text: #{response.text&.slice(0, 100).inspect}")
        debug_log("error: #{response.error.inspect}") if response.error

        unless response
          output "[gcore] Error: No response from API"
          break
        end

        if response.error && !response.function_call?
          output "[gcore] API Error: #{response.error}"
          break
        end

        if response.function_call?
          accumulated_text << response.text if response.text && !response.text.empty?

          function_call = response.function_calls.first
          tool_name = function_call[:name]
          tool_args = function_call[:args] || {}

          debug_log("Tool: #{tool_name}(#{tool_args.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')})")

          result = execute_tool(tool_name, tool_args)
          ConversationHistory.add_tool_call(tool_name, tool_args, result)

          debug_log("Tool error: #{result[:error]}") if result.is_a?(Hash) && result[:error]
        else
          accumulated_text << response.text if response.text && !response.text.empty?

          if accumulated_text.any?
            full_text = accumulated_text.join("\n")
            output full_text
            ConversationHistory.add_assistant_message(full_text)
          elsif Gcore.configuration.debug
            debug_log("Warning: Empty or unexpected response")
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

    def output(text)
      if @on_response
        @on_response.call(text)
      else
        puts text
      end
    end

    def debug_log(message)
      puts "[gcore] #{message}" if Gcore.configuration.debug
    end
  end
end
