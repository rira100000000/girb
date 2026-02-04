# frozen_string_literal: true

module Gcore
  module Providers
    # Base class for LLM providers
    #
    # Implement this class to add support for different LLM APIs.
    # See girb-ruby_llm, girb-gemini for examples.
    #
    # Example implementation:
    #
    #   class MyProvider < Gcore::Providers::Base
    #     def chat(messages:, system_prompt:, tools:, binding: nil)
    #       # Call your LLM API here
    #       # Return a Response object
    #       Response.new(text: "Hello!")
    #     end
    #   end
    #
    class Base
      # Send a chat request to the LLM
      #
      # @param messages [Array<Hash>] Conversation history in normalized format
      #   Each message has :role ("user", "assistant", "tool_call", "tool_result")
      #   and :content (String or Hash for tool calls/results)
      # @param system_prompt [String] System prompt for the LLM
      # @param tools [Array<Hash>] Tool definitions with :name, :description, :parameters
      # @param binding [Binding] Optional binding for tool execution context
      # @return [Response] Response object with text and/or function_calls
      def chat(messages:, system_prompt:, tools:, binding: nil)
        raise NotImplementedError, "#{self.class}#chat must be implemented"
      end

      # Response object returned by chat method
      class Response
        attr_reader :text, :function_calls, :error, :raw_response

        # @param text [String, nil] Text response from the LLM
        # @param function_calls [Array<Hash>, nil] Tool calls requested by the LLM
        #   Each call has :name (String) and :args (Hash)
        # @param error [String, nil] Error message if the request failed
        # @param raw_response [Object, nil] Raw response from the API for debugging
        def initialize(text: nil, function_calls: nil, error: nil, raw_response: nil)
          @text = text
          @function_calls = function_calls || []
          @error = error
          @raw_response = raw_response
        end

        # @return [Boolean] true if the LLM requested tool calls
        def function_call?
          @function_calls.any?
        end
      end
    end
  end
end
