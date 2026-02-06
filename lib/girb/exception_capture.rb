# frozen_string_literal: true

module Girb
  module ExceptionCapture
    @last_exception = nil
    @last_exception_binding = nil
    @trace_point = nil

    class << self
      attr_reader :last_exception, :last_exception_binding

      def capture(exception, binding = nil)
        @last_exception = {
          class: exception.class.name,
          message: exception.message,
          backtrace: exception.backtrace&.first(10),
          time: Time.now
        }
        @last_exception_binding = binding
      end

      def clear
        @last_exception = nil
        @last_exception_binding = nil
      end

      def install
        return if @trace_point

        @trace_point = TracePoint.new(:raise) do |tp|
          # IRB内部・Ruby内部の例外は除外
          next if tp.path&.include?("irb")
          next if tp.path&.include?("error_highlight")
          next if tp.path&.include?("reline")
          next if tp.path&.include?("readline")
          next if tp.path&.include?("rdoc")
          next if tp.path&.include?("/ri/")
          # forwardableは内部でSyntaxErrorを意図的に発生させてrescueする
          next if tp.path&.include?("forwardable")
          # rubygemsのrequireは最初にLoadErrorを発生させてからgemをアクティベートする
          next if tp.path&.include?("rubygems")
          next if tp.raised_exception.is_a?(SystemExit)
          next if tp.raised_exception.is_a?(Interrupt)
          # ErrorHighlight内部の例外を除外
          next if tp.raised_exception.class.name&.start_with?("ErrorHighlight::")

          capture(tp.raised_exception, tp.binding)
        end
        @trace_point.enable
      end

      def uninstall
        @trace_point&.disable
        @trace_point = nil
      end
    end
  end
end
