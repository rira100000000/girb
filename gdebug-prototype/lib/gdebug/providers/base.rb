# frozen_string_literal: true

module Gdebug
  module Providers
    # Base class for LLM providers
    # Gdebug can use girb providers directly
    #
    # Example:
    #   require "girb-ruby_llm"
    #
    #   Gdebug.configure do |c|
    #     c.provider = Girb::Providers::RubyLlm.new
    #   end
    #
    class Base
      # Send a chat request to the LLM
      #
      # @param messages [Array<Hash>] Conversation history in normalized format
      # @param system_prompt [String] System prompt
      # @param tools [Array<Hash>] Tool definitions
      # @param binding [Binding] Optional binding for tool execution
      # @return [Response] Response object with text and/or function_calls
      def chat(messages:, system_prompt:, tools:, binding: nil)
        raise NotImplementedError, "#{self.class}#chat must be implemented"
      end

      # Response object returned by chat method
      class Response
        attr_reader :text, :function_calls, :error, :raw_response

        def initialize(text: nil, function_calls: nil, error: nil, raw_response: nil)
          @text = text
          @function_calls = function_calls || []
          @error = error
          @raw_response = raw_response
        end

        def function_call?
          @function_calls.any?
        end
      end
    end
  end
end

# Allow using Girb providers directly
module Girb
  module Providers
    Base = Gdebug::Providers::Base unless defined?(Base)
  end
end
