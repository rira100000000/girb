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
        original_int_handler = setup_interrupt_handler
        @debug_command_queued = false

        begin
          loop do
            # Check for interrupt at start of loop
            if Girb::AutoContinue.interrupted?
              Girb::AutoContinue.clear_interrupt!
              handle_irb_interrupted
              break
            end

            process_with_tools(tools)

            # If a debug command was queued, exit immediately
            # The command needs to be executed by IRB first, then DebugIntegration handles auto-continue
            if @debug_command_queued
              break
            end

            # Check for interrupt after API call (Ctrl+C during request)
            if Girb::AutoContinue.interrupted?
              Girb::AutoContinue.clear_interrupt!
              handle_irb_interrupted
              break
            end

            break unless Girb::AutoContinue.active?

            auto_continue_count += 1
            if auto_continue_count >= Girb::AutoContinue::MAX_ITERATIONS
              handle_irb_limit_reached
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
        ensure
          restore_interrupt_handler(original_int_handler)
          # Only reset AutoContinue if no debug command was queued
          # (it will be transferred to DebugIntegration in IrbDebugHook)
          unless @debug_command_queued
            Girb::AutoContinue.reset!
          end
          Girb::AutoContinue.clear_interrupt!
        end
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
        # Check for interrupt at start of each iteration
        if check_interrupted?
          puts "\n[girb] Interrupted by user (Ctrl+C)"
          break
        end

        iterations += 1
        if iterations > MAX_TOOL_ITERATIONS
          puts "\n[girb] Tool iteration limit reached"
          break
        end

        messages = ConversationHistory.to_normalized
        begin
          response = @provider.chat(
            messages: messages,
            system_prompt: @system_prompt,
            tools: tools,
            binding: @current_binding
          )
        rescue Interrupt => e
          puts "\n[girb] Interrupted by user (Ctrl+C)"
          Girb::AutoContinue.interrupt! unless @debug_mode
          Girb::DebugIntegration.interrupt! if @debug_mode && defined?(Girb::DebugIntegration)
          break
        rescue Exception => e
          # IRB::Abort and similar exceptions
          if e.class.name.include?("Abort") || e.class.name.include?("Interrupt")
            puts "\n[girb] Interrupted by user (Ctrl+C)"
            Girb::AutoContinue.interrupt! unless @debug_mode
            Girb::DebugIntegration.interrupt! if @debug_mode && defined?(Girb::DebugIntegration)
            break
          else
            raise
          end
        end

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

            # If run_debug_command was called, we need to exit the tool loop
            # so the debugger/IRB can execute the pending commands
            if tool_name == "run_debug_command"
              debug_command_called = true
              # In IRB mode, mark that we've queued a debug command
              # This will prevent the auto-continue loop from continuing
              @debug_command_queued = true unless @debug_mode
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

    def setup_interrupt_handler
      trap("INT") do
        Girb::AutoContinue.interrupt!
      end
    end

    def check_interrupted?
      if @debug_mode
        defined?(Girb::DebugIntegration) && Girb::DebugIntegration.interrupted?
      else
        Girb::AutoContinue.interrupted?
      end
    end

    def restore_interrupt_handler(original_handler)
      if original_handler
        trap("INT", original_handler)
      else
        trap("INT", "DEFAULT")
      end
    end

    def handle_irb_interrupted
      return unless @current_binding

      new_context = create_context_builder(@current_binding, @irb_context).build
      interrupt_message = "(System: User interrupted with Ctrl+C. " \
                          "Briefly summarize your progress so far. " \
                          "Tell the user where you stopped and how to continue if needed.)"
      continuation_builder = create_prompt_builder(interrupt_message, new_context)
      ConversationHistory.add_user_message(continuation_builder.user_message)
      process_with_tools(build_tools)
    rescue StandardError => e
      puts "[girb] Error summarizing: #{e.message}" if Girb.configuration.debug
    end

    def handle_irb_limit_reached
      puts "\n[girb] Auto-continue limit reached (#{Girb::AutoContinue::MAX_ITERATIONS})"
      return unless @current_binding

      new_context = create_context_builder(@current_binding, @irb_context).build
      limit_message = "(System: Auto-continue limit (#{Girb::AutoContinue::MAX_ITERATIONS}) reached. " \
                      "Summarize your progress so far and tell the user what was accomplished. " \
                      "If the task is not complete, explain what remains and instruct the user " \
                      "to continue with a follow-up request.)"
      continuation_builder = create_prompt_builder(limit_message, new_context)
      ConversationHistory.add_user_message(continuation_builder.user_message)
      process_with_tools(build_tools)
    rescue StandardError => e
      puts "[girb] Error summarizing: #{e.message}" if Girb.configuration.debug
    end
  end
end
