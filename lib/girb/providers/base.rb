# frozen_string_literal: true

module Girb
  module Providers
    # Base class for LLM providers
    # Implement this class to add support for new LLM providers
    #
    # Example:
    #   class MyProvider < Girb::Providers::Base
    #     def chat(messages:, system_prompt:, tools:)
    #       # Call your LLM API
    #       # Return Response object
    #     end
    #   end
    #
    #   Girb.configure do |c|
    #     c.provider = MyProvider.new(api_key: "...")
    #   end
    #
    class Base
      # Send a chat request to the LLM
      #
      # @param messages [Array<Hash>] Conversation history in normalized format
      #   Each message has :role (:user, :assistant, :tool_call, :tool_result) and :content
      # @param system_prompt [String] System prompt
      # @param tools [Array<Hash>] Tool definitions in normalized format
      # @param binding [Binding] Optional binding for tool execution (used by some providers)
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

      # Normalized tool definition format
      # Providers should convert this to their specific format
      #
      # Example:
      #   {
      #     name: "evaluate_code",
      #     description: "Execute Ruby code",
      #     parameters: {
      #       type: "object",
      #       properties: {
      #         code: { type: "string", description: "Ruby code to execute" }
      #       },
      #       required: ["code"]
      #     }
      #   }
    end
  end
end
