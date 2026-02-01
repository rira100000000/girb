# frozen_string_literal: true

module Girb
  class Configuration
    attr_accessor :gemini_api_key, :model, :debug, :custom_prompt

    def initialize
      @gemini_api_key = ENV["GEMINI_API_KEY"]
      @model = "gemini-2.5-flash"
      @debug = ENV["GIRB_DEBUG"] == "1"
      @custom_prompt = nil
    end
  end
end
