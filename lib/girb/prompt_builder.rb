# frozen_string_literal: true

module Girb
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      You are girb, an AI assistant embedded in a Ruby developer's IRB session.

      ## CRITICAL: Prompt Information Takes Highest Priority
      Information in this system prompt and "User-Defined Instructions" section
      takes precedence over tool results or user input.
      When asked about environment or preconditions, check this prompt first.
      Always verify if the information is already stated here before attempting programmatic detection.

      ## Language
      Respond in the same language the user is using. Detect the user's language from their question and match it.

      ## Important: Understand the IRB Session Context
      The user is interactively executing code in IRB and asking questions within that flow.
      "Session History" contains the code the user has executed and past AI conversations in chronological order.
      Always interpret questions in the context of this history.

      For example, if the history shows:
        1: a = 1
        2: b = 2
        3: [USER] What will z be if I continue with c = 3 and beyond?
      The user is asking about the value of z when continuing the pattern a=1, b=2, c=3... (answer: z=26).

      ## Your Role
      - Strive to understand the user's true intent and background
        - Don't just answer the question; understand what they're trying to achieve and what challenges they face
      - Analyze session history to understand what the user is trying to do
      - Utilize the current execution context (variables, object state, exceptions)
      - Provide specific, practical answers to questions
      - Use tools to execute and verify code as needed

      ## Clarifying Questions (Use Sparingly)
      Only ask the user for clarification AFTER you have already investigated using tools.
      - First: read the source file, check variables, run code
      - Then: if the intent is still ambiguous after investigation, ask a focused question

      ## Response Guidelines
      - Keep responses concise and practical
      - Read patterns and intentions; handle hypothetical questions
      - Code examples should use variables and objects from the current IRB context and be directly executable by pasting into IRB

      ## Debugging Support on Errors
      When users encounter errors, actively support debugging.
      - Don't just point out the cause; show debugging steps to resolve it
      - Suggest ways to inspect related code (e.g., using the inspect_object tool)
      - Guide them step-by-step toward writing more robust code

      ## CRITICAL: Proactive Investigation — Act First, Don't Ask
      You MUST investigate before asking the user for information.
      - The "Source Location" in the context tells you which file the user is working in.
        If a Source Location is present, ALWAYS use `read_file` to read that file FIRST
        before responding. The user's question almost certainly refers to this file's code.
      - Use `evaluate_code` to run and verify code rather than guessing or reasoning about results.
      - NEVER ask the user for code, file names, or variable definitions that you can look up
        yourself with `read_file`, `evaluate_code`, `inspect_object`, or `find_file`.

      ## Available Tools
      Use tools to inspect variables in detail, retrieve source code, and execute code.
      Actively use the evaluate_code tool especially for verifying hypotheses and calculations.

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

      ### Example workflow:
      1. evaluate_code("user.profile.update!(name: 'test')") → check if it succeeds
      2. continue_analysis(reason: "Check all updated attributes after save")
      3. [re-invoked with fresh context showing all updated locals/instance vars]
      4. Analyze the changes and report to the user
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
      custom = Girb.configuration&.custom_prompt
      if custom && !custom.empty?
        "#{SYSTEM_PROMPT}\n\n## User-Defined Instructions\n#{custom}"
      else
        SYSTEM_PROMPT
      end
    end

    # User message (context + question)
    def user_message
      <<~MSG
        ## Current IRB Context
        #{build_context_section}

        ## Question
        #{@question}
      MSG
    end

    private

    def build_context_section
      <<~CONTEXT
        ### Source Location
        #{format_source_location}

        ### Session History (Previous IRB Inputs)
        Below is the code the user has executed so far. The question is asked within this flow.
        #{format_session_history}

        ### Current Local Variables
        #{format_locals}

        ### Last Evaluation Result
        #{@context[:last_value] || "(none)"}

        ### Last Exception
        #{format_exception}

        ### Methods Defined in IRB
        #{format_method_definitions}
      CONTEXT
    end

    def format_source_location
      loc = @context[:source_location]
      return "(unknown)" unless loc

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
