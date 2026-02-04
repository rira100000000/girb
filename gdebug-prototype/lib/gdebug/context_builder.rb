# frozen_string_literal: true

module Gdebug
  class ContextBuilder
    MAX_INSPECT_LENGTH = 500

    def initialize(binding, thread_client: nil)
      @binding = binding
      @thread_client = thread_client
    end

    def build
      {
        source_location: capture_source_location,
        local_variables: capture_locals,
        instance_variables: capture_instance_variables,
        self_info: capture_self,
        backtrace: capture_backtrace,
        breakpoint_info: capture_breakpoint_info
      }
    end

    private

    def capture_source_location
      loc = @binding.source_location
      return nil unless loc

      file, line = loc
      {
        file: file,
        line: line
      }
    rescue StandardError
      nil
    end

    def capture_locals
      @binding.local_variables.to_h do |var|
        value = @binding.local_variable_get(var)
        [var, safe_inspect(value)]
      end
    end

    def capture_instance_variables
      obj = @binding.receiver
      obj.instance_variables.to_h do |var|
        value = obj.instance_variable_get(var)
        [var, safe_inspect(value)]
      end
    rescue StandardError
      {}
    end

    def capture_self
      obj = @binding.receiver
      {
        class: obj.class.name,
        inspect: safe_inspect(obj),
        methods: obj.methods(false).first(20)
      }
    end

    def capture_backtrace
      return nil unless @thread_client

      # Get backtrace from debug gem's thread client if available
      @thread_client.current_frame&.location&.to_s
    rescue StandardError
      nil
    end

    def capture_breakpoint_info
      return nil unless defined?(DEBUGGER__) && DEBUGGER__.respond_to?(:breakpoints)

      DEBUGGER__.breakpoints.map do |bp|
        { type: bp.class.name, location: bp.to_s }
      end
    rescue StandardError
      nil
    end

    def safe_inspect(obj, max_length: MAX_INSPECT_LENGTH)
      if defined?(ActiveRecord::Base) && obj.is_a?(ActiveRecord::Base)
        return inspect_active_record(obj)
      end

      result = obj.inspect
      result.length > max_length ? "#{result[0, max_length]}..." : result
    rescue StandardError => e
      "#<#{obj.class} (inspect failed: #{e.message})>"
    end

    def inspect_active_record(obj)
      {
        class: obj.class.name,
        id: obj.try(:id),
        attributes: obj.attributes,
        new_record: obj.new_record?,
        changed: obj.changed?,
        errors: obj.errors.full_messages
      }
    end
  end
end
