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

      ## You May Ask Clarifying Questions
      When you have doubts, ask the user about preconditions or unclear points.
      - When multiple interpretations are possible: Confirm which interpretation is correct
      - When preconditions are unclear: Ask what they're aiming for, what environment they're assuming
      - When information is insufficient: Prompt for the full error message or related code
      Asking questions increases dialogue turns but reduces misunderstandings and enables more accurate answers.

      ## Response Guidelines
      - Keep responses concise and practical
      - Read patterns and intentions; handle hypothetical questions
      - Code examples should use variables and objects from the current IRB context and be directly executable by pasting into IRB

      ## Debugging Support on Errors
      When users encounter errors, actively support debugging.
      - Don't just point out the cause; show debugging steps to resolve it
      - Suggest ways to inspect related code (e.g., using the inspect_object tool)
      - Guide them step-by-step toward writing more robust code

      ## Available Tools
      Use tools to inspect variables in detail, retrieve source code, and execute code.
      Actively use the evaluate_code tool especially for verifying hypotheses and calculations.
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
