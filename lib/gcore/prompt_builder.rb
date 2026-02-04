# frozen_string_literal: true

module Gcore
  # Base prompt builder for AI interactions
  # Subclass this to customize prompts for different tools (girb, gdebug)
  class PromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      You are an AI assistant embedded in a Ruby debugging session.
      You have access to the current execution context and can help developers
      understand and debug their code.

      ## Language
      Respond in the same language the user is using.

      ## Your Capabilities
      - Inspect local variables, instance variables, and objects
      - Evaluate Ruby code in the current context
      - Read source code of methods and classes
      - Search for files in the project
      - Explain code behavior and suggest fixes

      ## Response Guidelines
      - Keep responses concise and actionable
      - Use code examples when helpful
      - Explain complex issues step by step
      - Suggest specific debugging strategies

      ## Debugging Support
      When users encounter errors:
      - Don't just point out the cause; show debugging steps
      - Suggest ways to inspect related code
      - Guide them step-by-step toward a solution
    PROMPT

    def initialize(question, context)
      @question = question
      @context = context
    end

    def system_prompt
      base = self.class::SYSTEM_PROMPT
      custom = Gcore.configuration&.custom_prompt
      if custom && !custom.empty?
        "#{base}\n\n## User-Defined Instructions\n#{custom}"
      else
        base
      end
    end

    def user_message
      <<~MSG
        ## Current Context
        #{build_context_section}

        ## Question
        #{@question}
      MSG
    end

    protected

    def build_context_section
      sections = []
      sections << format_section("Source Location", format_source_location)
      sections << format_section("Local Variables", format_hash(@context[:local_variables]))
      sections << format_section("Instance Variables", format_hash(@context[:instance_variables]))
      sections << format_section("Current Object (self)", format_self_info)
      sections << format_section("Backtrace", @context[:backtrace])
      sections.compact.join("\n\n")
    end

    def format_section(title, content)
      return nil if content.nil? || content.empty? || content == "(none)"

      "### #{title}\n#{content}"
    end

    def format_source_location
      loc = @context[:source_location]
      return "(unknown)" unless loc

      "File: #{loc[:file]}\nLine: #{loc[:line]}"
    end

    def format_hash(hash)
      return "(none)" if hash.nil? || hash.empty?

      hash.map { |name, value| "- #{name}: #{value}" }.join("\n")
    end

    def format_self_info
      info = @context[:self_info]
      return "(unknown)" unless info && !info.empty?

      lines = ["Class: #{info[:class]}"]
      lines << "inspect: #{info[:inspect]}" if info[:inspect]
      lines << "Defined methods: #{info[:methods].join(', ')}" if info[:methods]&.any?
      lines.join("\n")
    end
  end
end
