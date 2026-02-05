# frozen_string_literal: true

require_relative "auto_continue"
require_relative "conversation_history"
require_relative "providers/base"
require_relative "debug_context_builder"
require_relative "debug_prompt_builder"

module Girb
  class AiClient
    MAX_TOOL_ITERATIONS = 10

    def initialize
      @provider = Girb.configuration.provider!
    end

    def ask(question, context, binding: nil, line_no: nil, irb_context: nil, debug_mode: false)
      @current_binding = binding
      @current_line_no = line_no
      @irb_context = irb_context
      @debug_mode = debug_mode
      @reasoning_log = []

      prompt_builder = create_prompt_builder(question, context)
      @system_prompt = prompt_builder.system_prompt
      user_message = prompt_builder.user_message

      ConversationHistory.add_user_message(user_message)

      tools = build_tools

      # In debug mode, auto-continue is handled by DebugIntegration, not here
      if @debug_mode
        process_with_tools(tools)
      else
        auto_continue_count = 0

        loop do
          process_with_tools(tools)

          break unless Girb::AutoContinue.active?

          auto_continue_count += 1
          if auto_continue_count >= Girb::AutoContinue::MAX_ITERATIONS
            puts "\n[girb] Auto-continue limit reached (#{Girb::AutoContinue::MAX_ITERATIONS})"
            break
          end

          Girb::AutoContinue.reset!

          # Rebuild context with current binding state
          new_context = create_context_builder(@current_binding, @irb_context).build
          continuation = "(auto-continue: Your previous action has been completed. " \
                         "Here is the updated context. Continue your investigation.)"
          continuation_builder = create_prompt_builder(continuation, new_context)
          ConversationHistory.add_user_message(continuation_builder.user_message)
        end

        Girb::AutoContinue.reset!
      end
    end

    private

    def create_prompt_builder(question, context)
      if @debug_mode
        DebugPromptBuilder.new(question, context)
      else
        PromptBuilder.new(question, context)
      end
    end

    def create_context_builder(binding, irb_context)
      if @debug_mode
        DebugContextBuilder.new(binding)
      else
        ContextBuilder.new(binding, irb_context)
      end
    end

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
          puts "\n[girb] Tool iteration limit reached"
          break
        end

        messages = ConversationHistory.to_normalized
        response = @provider.chat(
          messages: messages,
          system_prompt: @system_prompt,
          tools: tools,
          binding: @current_binding
        )

        if Girb.configuration.debug
          puts "[girb] function_calls: #{response.function_calls.inspect}"
          puts "[girb] text: #{response.text&.slice(0, 100).inspect}"
          puts "[girb] error: #{response.error.inspect}" if response.error
        end

        unless response
          puts "[girb] Error: No response from API"
          break
        end

        if response.error && !response.function_call?
          puts "[girb] API Error: #{response.error}"
          break
        end

        if response.function_call?
          # Accumulate text that comes with function calls
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          debug_command_called = false

          response.function_calls.each do |function_call|
            tool_name = function_call[:name]
            tool_args = function_call[:args] || {}
            tool_id = function_call[:id]

            if Girb.configuration.debug
              puts "[girb] Tool: #{tool_name}(#{tool_args.map { |k, v| "#{k}: #{v.inspect}" }.join(', ')})"
            end

            result = execute_tool(tool_name, tool_args)

            @reasoning_log << {
              tool: tool_name,
              args: tool_args,
              result: result
            }

            ConversationHistory.add_tool_call(tool_name, tool_args, result, id: tool_id)

            if Girb.configuration.debug && result.is_a?(Hash) && result[:error]
              puts "[girb] Tool error: #{result[:error]}"
            end

            # In debug mode, if run_debug_command was called, we need to exit
            # the tool loop so the debugger can execute the pending commands
            if @debug_mode && tool_name == "run_debug_command"
              debug_command_called = true
            end
          end

          # Exit tool loop if debug command was called - let debugger take over
          if debug_command_called
            # Save accumulated text and pending tool calls as assistant message
            text = accumulated_text.any? ? accumulated_text.join("\n") : ""
            ConversationHistory.add_assistant_message(text)
            record_ai_response(text) unless text.empty?
            puts text unless text.empty?
            break
          end
        else
          # Text response
          if response.text && !response.text.empty?
            accumulated_text << response.text
          end

          if accumulated_text.any?
            full_text = accumulated_text.join("\n")
            puts full_text
            ConversationHistory.add_assistant_message(full_text)
            record_ai_response(full_text)
          elsif Girb.configuration.debug
            puts "[girb] Warning: Empty or unexpected response"
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

    def record_ai_response(response)
      if @debug_mode
        require_relative "debug_session_history"
        DebugSessionHistory.record_ai_response(response)
      elsif @current_line_no
        reasoning = @reasoning_log.empty? ? nil : format_reasoning
        SessionHistory.record_ai_response(@current_line_no, response, reasoning)
      end
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
