# frozen_string_literal: true

module Girb
  module AutoContinue
    MAX_ITERATIONS = 20

    class << self
      def active?
        @active || false
      end

      def request!
        @active = true
      end

      def reset!
        @active = false
      end
    end
  end
end
