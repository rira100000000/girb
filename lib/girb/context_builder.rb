# frozen_string_literal: true

require_relative "session_history"

module Girb
  # IRB-specific context builder that extends Gcore::ContextBuilder
  # Adds IRB session history, last value, and exception capture
  class ContextBuilder < Gcore::ContextBuilder
    def initialize(binding, irb_context = nil)
      super(binding)
      @irb_context = irb_context
    end

    protected

    # Add IRB-specific context to the base context
    def additional_context
      {
        last_value: capture_last_value,
        last_exception: ExceptionCapture.last_exception,
        session_history: session_history_with_line_numbers,
        method_definitions: session_method_definitions
      }
    end

    private

    def capture_last_value
      return nil unless @irb_context

      safe_inspect(@irb_context.last_value)
    end

    def session_history_with_line_numbers
      SessionHistory.all_with_line_numbers
    rescue StandardError
      []
    end

    def session_method_definitions
      SessionHistory.method_index
    rescue StandardError
      []
    end
  end
end
