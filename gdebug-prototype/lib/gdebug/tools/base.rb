# frozen_string_literal: true

module Gdebug
  module Tools
    class Base
      class << self
        def tool_name
          name.split("::").last.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/^_/, "")
        end

        def description
          raise NotImplementedError, "#{name} must implement .description"
        end

        def parameters
          raise NotImplementedError, "#{name} must implement .parameters"
        end

        def available?
          true
        end
      end

      def execute(binding, **params)
        raise NotImplementedError, "#{self.class.name} must implement #execute"
      end

      protected

      def safe_inspect(obj, max_length: 1000)
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
end
