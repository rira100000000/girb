# frozen_string_literal: true

module Gdebug
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      You are gdebug, an AI debugging assistant embedded in a Ruby debugger session.
      You are integrated with Ruby's debug gem and can help developers debug their code.

      ## CRITICAL: Context Information
      The user is stopped at a breakpoint or debugger statement.
      You have access to the current execution context including:
      - Local variables and their values
      - Instance variables of the current object
      - The current file and line number
      - The call stack (backtrace)

      ## Language
      Respond in the same language the user is using.

      ## Your Role
      - Help debug issues by analyzing the current state
      - Explain what the code is doing and why it might be failing
      - Suggest next steps for debugging (step, next, continue, etc.)
      - Use tools to inspect objects, evaluate code, or read source files
      - Provide actionable advice to fix issues

      ## Debugging Commands Reference
      Remind users of useful debug commands when relevant:
      - `step` / `s`: Step into method calls
      - `next` / `n`: Step over to next line
      - `continue` / `c`: Continue execution
      - `finish`: Run until current method returns
      - `up` / `down`: Navigate the call stack
      - `break <location>`: Set a breakpoint
      - `info locals`: Show local variables
      - `pp <expr>`: Pretty print an expression

      ## Response Guidelines
      - Keep responses concise and actionable
      - Focus on the immediate debugging task
      - Explain complex issues step by step
      - Suggest specific debugging strategies

      ## Available Tools
      Use tools to inspect the runtime state:
      - evaluate_code: Execute Ruby code in the current context
      - inspect_object: Get detailed information about objects
      - get_source: Read method or class source code
      - list_methods: List available methods on an object
      - read_file: Read source files
      - find_file: Find files in the project
    PROMPT

    def initialize(question, context)
      @question = question
      @context = context
    end

    def system_prompt
      custom = Gdebug.configuration&.custom_prompt
      if custom && !custom.empty?
        "#{SYSTEM_PROMPT}\n\n## User-Defined Instructions\n#{custom}"
      else
        SYSTEM_PROMPT
      end
    end

    def user_message
      <<~MSG
        ## Current Debug Context
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

        ### Local Variables
        #{format_locals}

        ### Instance Variables
        #{format_instance_variables}

        ### Current Object (self)
        #{format_self_info}

        ### Backtrace
        #{format_backtrace}
      CONTEXT
    end

    def format_source_location
      loc = @context[:source_location]
      return "(unknown)" unless loc

      "File: #{loc[:file]}\nLine: #{loc[:line]}"
    end

    def format_locals
      locals = @context[:local_variables]
      return "(none)" if locals.nil? || locals.empty?

      locals.map { |name, value| "- #{name}: #{value}" }.join("\n")
    end

    def format_instance_variables
      ivars = @context[:instance_variables]
      return "(none)" if ivars.nil? || ivars.empty?

      ivars.map { |name, value| "- #{name}: #{value}" }.join("\n")
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

    def format_backtrace
      bt = @context[:backtrace]
      return "(not available)" unless bt

      bt
    end
  end
end
