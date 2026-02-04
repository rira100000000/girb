# frozen_string_literal: true

module Gcore
  # Builds context information from a Ruby binding
  # Used by AI to understand the current execution state
  class ContextBuilder
    MAX_INSPECT_LENGTH = 500

    def initialize(binding, options = {})
      @binding = binding
      @options = options
    end

    def build
      {
        source_location: capture_source_location,
        local_variables: capture_locals,
        instance_variables: capture_instance_variables,
        class_variables: capture_class_variables,
        global_variables: capture_global_variables,
        self_info: capture_self,
        backtrace: capture_backtrace
      }.merge(additional_context)
    end

    protected

    # Override in subclasses to add additional context
    # e.g., IRB session history, debug gem frame info
    def additional_context
      {}
    end

    private

    def capture_source_location
      loc = @binding.source_location
      return nil unless loc

      file, line = loc
      { file: file, line: line }
    rescue StandardError
      nil
    end

    def capture_locals
      @binding.local_variables.to_h do |var|
        value = @binding.local_variable_get(var)
        [var, safe_inspect(value)]
      end
    rescue StandardError
      {}
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

    def capture_class_variables
      obj = @binding.receiver
      klass = obj.is_a?(Class) ? obj : obj.class
      klass.class_variables.to_h do |var|
        value = klass.class_variable_get(var)
        [var, safe_inspect(value)]
      end
    rescue StandardError
      {}
    end

    def capture_global_variables
      important_globals = %i[$! $@ $~ $& $` $' $+ $1 $2 $3 $stdin $stdout $stderr $DEBUG $VERBOSE]
      important_globals.each_with_object({}) do |var, hash|
        next unless global_variables.include?(var)

        value = eval(var.to_s) # rubocop:disable Security/Eval
        hash[var] = safe_inspect(value) unless value.nil?
      rescue StandardError
        next
      end
    end

    def capture_self
      obj = @binding.receiver
      {
        class: obj.class.name,
        inspect: safe_inspect(obj),
        methods: obj.methods(false).first(20)
      }
    rescue StandardError
      {}
    end

    def capture_backtrace
      caller_locations(4, 10)&.map(&:to_s)&.join("\n")
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
      }.to_s
    end
  end
end
