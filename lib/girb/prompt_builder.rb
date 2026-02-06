# frozen_string_literal: true

module Girb
  class PromptBuilder
    # Common prompt shared across all IRB modes
    COMMON_PROMPT = <<~PROMPT
      You are girb, an AI assistant embedded in a Ruby developer's session.

      ## CRITICAL: Prompt Information Takes Highest Priority
      Information in this system prompt and "User-Defined Instructions" section
      takes precedence over tool results or user input.
      When asked about environment or preconditions, check this prompt first.
      Always verify if the information is already stated here before attempting programmatic detection.

      ## Language
      Respond in the same language the user is using. Detect the user's language from their question and match it.

      ## Clarifying Questions (Use Sparingly)
      Only ask the user for clarification AFTER you have already investigated using tools.
      - First: read the source file, check variables, run code
      - Then: if the intent is still ambiguous after investigation, ask a focused question

      ## Response Guidelines
      - Keep responses concise and practical
      - Read patterns and intentions; handle hypothetical questions
      - Code examples should use variables and objects from the current context and be directly executable

      ## Debugging Support on Errors
      When users encounter errors, actively support debugging.
      - Don't just point out the cause; show debugging steps to resolve it
      - Suggest ways to inspect related code (e.g., using the inspect_object tool)
      - Guide them step-by-step toward writing more robust code

      ## CRITICAL: Proactive Investigation — Act First, Don't Ask
      You MUST investigate before asking the user for information.
      - Use `evaluate_code` to run and verify code rather than guessing or reasoning about results.
      - NEVER ask the user for code, file names, or variable definitions that you can look up
        yourself with `read_file`, `evaluate_code`, `inspect_object`, or `find_file`.

      ## Available Tools
      Use tools to inspect variables in detail, retrieve source code, and execute code.
      Actively use the evaluate_code tool especially for verifying hypotheses and calculations.
    PROMPT

    # Prompt specific to breakpoint mode (binding.girb / binding.irb)
    BREAKPOINT_PROMPT = <<~PROMPT
      ## Mode: Breakpoint (binding.girb)
      You are at a BREAKPOINT in the user's Ruby script. Execution is paused at this exact line.

      ### CRITICAL: Understanding Breakpoint Context
      - Code BEFORE this line has already executed (variables are set)
      - Code AFTER this line has NOT executed yet
      - The user's questions about "the code", "this loop", "this method" refer to the code in the SOURCE FILE
      - ALWAYS read the source file FIRST using `read_file` to understand what code exists

      ### Your Primary Task
      - Help the user understand, debug, or simulate the code that is ABOUT TO execute
      - When asked to "run the code" or "execute this loop", execute the ACTUAL code from the file
      - When asked to track variables, run the actual code and report real results
      - NEVER invent or substitute code - always use what's in the file

      ### Example: User says "run this loop and track x"
      1. Read the source file to see the actual loop code
      2. Execute that exact code using evaluate_code
      3. Report the actual results

      ### WRONG approach:
      - Guessing what the code might do
      - Writing your own version of the code
      - Asking the user what the code is when you can read the file
    PROMPT

    # Prompt specific to interactive IRB mode (girb command)
    INTERACTIVE_IRB_PROMPT = <<~PROMPT
      ## Mode: Interactive IRB Session
      The user is in an interactive IRB session, typing code and questions directly.

      ### Understanding the Session
      - "Session History" contains the code the user has executed and past AI conversations
      - Always interpret questions in the context of this history
      - Variables and objects from past commands are available in the current context

      ### Example Context
      If the history shows:
        1: a = 1
        2: b = 2
        3: [USER] What will z be if I continue with c = 3 and beyond?
      The user is asking about the value of z when continuing the pattern a=1, b=2, c=3... (answer: z=26).

      ### Your Role
      - Help with code exploration and experimentation
      - Answer questions about Ruby, gems, and the current session state
      - Assist with building and testing code interactively
    PROMPT

    # Prompt specific to Rails console mode
    RAILS_CONSOLE_PROMPT = <<~PROMPT
      ## Mode: Rails Console
      The user is in a Rails console with full access to the application's models and services.

      ### Rails-Specific Capabilities
      - You can query ActiveRecord models directly
      - Use `model_info` tool to get schema information
      - Use `query_model` tool to execute database queries safely
      - Access to Rails helpers, routes, and application configuration

      ### Best Practices
      - Be careful with destructive operations (update!, destroy, etc.) - warn the user
      - Use transactions when demonstrating data modifications
      - Suggest using `find_by` or `where` instead of `find` to avoid exceptions
      - Remember that console changes affect the real database (unless in sandbox mode)
    PROMPT

    # Autonomous investigation prompt (shared)
    CONTINUE_ANALYSIS_PROMPT = <<~PROMPT
      ## Autonomous Investigation with continue_analysis
      When you need to execute code that changes state AND then see the full updated context
      (all local variables, instance variables, last value, etc.), use the `continue_analysis` tool.

      After you call `continue_analysis`, your current response will be sent, and then you will be
      automatically re-invoked with a refreshed context showing all current variable values.

      ### When to use continue_analysis:
      - After evaluating code that modifies variables, when you need to see the full picture
      - When iteratively debugging: change something → check state → change more
      - When you need to verify side effects of an operation across multiple variables

      ### When NOT to use continue_analysis:
      - When you can get the information you need with evaluate_code or inspect_object directly
      - When you've found your answer and want to report to the user
      - For simple one-shot investigations
    PROMPT

    def initialize(question, context)
      @question = question
      @context = context
    end

    # Legacy single prompt format (for backward compatibility)
    def build
      <<~PROMPT
        #{system_prompt}

        #{build_context_section}

        ## Question
        #{@question}
      PROMPT
    end

    # System prompt (shared across conversation)
    def system_prompt
      prompt = COMMON_PROMPT + "\n" + mode_specific_prompt + "\n" + CONTINUE_ANALYSIS_PROMPT

      custom = Girb.configuration&.custom_prompt
      if custom && !custom.empty?
        prompt + "\n\n## User-Defined Instructions\n#{custom}"
      else
        prompt
      end
    end

    # User message (context + question)
    def user_message
      <<~MSG
        ## Current Context
        #{build_context_section}

        ## Question
        #{@question}
      MSG
    end

    private

    def mode_specific_prompt
      case detect_mode
      when :breakpoint
        BREAKPOINT_PROMPT
      when :rails
        RAILS_CONSOLE_PROMPT
      else
        INTERACTIVE_IRB_PROMPT
      end
    end

    def detect_mode
      loc = @context[:source_location]

      # Check for breakpoint mode: source is a real file (not irb/eval)
      if loc && loc[:file]
        file = loc[:file].to_s
        unless file.start_with?("(") || file.include?("irb") || file.include?("eval")
          return :breakpoint
        end
      end

      # Check for Rails mode
      return :rails if defined?(Rails)

      # Default: interactive IRB
      :interactive
    end

    def build_context_section
      sections = []
      sections << "### Source Location\n#{format_source_location}"
      sections << "### Session History (Previous Inputs)\n#{format_session_history}"
      sections << "### Current Local Variables\n#{format_locals}"
      sections << "### Last Evaluation Result\n#{@context[:last_value] || "(none)"}"
      sections << "### Last Exception\n#{format_exception}"
      sections << "### Methods Defined in Session\n#{format_method_definitions}"
      sections.join("\n\n")
    end

    def format_source_location
      loc = @context[:source_location]
      return "(interactive session)" unless loc

      "File: #{loc[:file]}\nLine: #{loc[:line]}"
    end

    def format_locals
      return "(none)" if @context[:local_variables].nil? || @context[:local_variables].empty?

      @context[:local_variables].map do |name, value|
        "- #{name}: #{value}"
      end.join("\n")
    end

    def format_self_info
      info = @context[:self_info]
      return "(unknown)" unless info

      lines = ["Class: #{info[:class]}"]
      lines << "inspect: #{info[:inspect]}"
      if info[:methods]&.any?
        lines << "Defined methods: #{info[:methods].join(', ')}"
      end
      lines.join("\n")
    end

    def format_exception
      exc = @context[:last_exception]
      return "(none)" unless exc

      <<~EXC
        Class: #{exc[:class]}
        Message: #{exc[:message]}
        Time: #{exc[:time]}
        Backtrace:
        #{exc[:backtrace]&.map { |l| "  #{l}" }&.join("\n")}
      EXC
    end

    def format_session_history
      history = @context[:session_history]
      return "(none)" if history.nil? || history.empty?

      history.join("\n")
    end

    def format_method_definitions
      methods = @context[:method_definitions]
      return "(none)" if methods.nil? || methods.empty?

      methods.join("\n")
    end
  end
end
