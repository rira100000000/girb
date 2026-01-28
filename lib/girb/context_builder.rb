# frozen_string_literal: true

module Girb
  class ContextBuilder
    MAX_INSPECT_LENGTH = 500

    def initialize(binding, irb_context = nil)
      @binding = binding
      @irb_context = irb_context
    end

    def build
      {
        local_variables: capture_locals,
        instance_variables: capture_instance_variables,
        class_variables: capture_class_variables,
        global_variables: capture_global_variables,
        self_info: capture_self,
        last_value: capture_last_value,
        last_exception: ExceptionCapture.last_exception,
        history: recent_history
      }
    end

    private

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
      # よく使われる重要なグローバル変数のみ収集（全部は多すぎる）
      important_globals = %i[$! $@ $~ $& $` $' $+ $1 $2 $3 $stdin $stdout $stderr $DEBUG $VERBOSE $LOAD_PATH $LOADED_FEATURES]
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
    end

    def capture_last_value
      return nil unless @irb_context

      safe_inspect(@irb_context.last_value)
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

    def recent_history
      if defined?(Reline::HISTORY) && Reline::HISTORY.respond_to?(:to_a)
        Reline::HISTORY.to_a.last(5)
      elsif defined?(Readline::HISTORY) && Readline::HISTORY.respond_to?(:to_a)
        Readline::HISTORY.to_a.last(5)
      else
        []
      end
    rescue StandardError
      []
    end
  end
end
