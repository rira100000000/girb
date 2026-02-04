# frozen_string_literal: true

require_relative "base"

module Gdebug
  module Tools
    class GetSource < Base
      MAX_SOURCE_LINES = 50

      class << self
        def description
          "Get the source code of a method or class definition. " \
          "Use 'Class#method' for instance methods, 'Class.method' for class methods."
        end

        def parameters
          {
            type: "object",
            properties: {
              target: {
                type: "string",
                description: "Class or method to get source for (e.g., 'User', 'User#save', 'User.find')"
              }
            },
            required: ["target"]
          }
        end
      end

      def execute(binding, target:)
        if target.include?("#")
          get_instance_method_source(binding, target)
        elsif target.include?(".")
          get_class_method_source(binding, target)
        else
          get_class_info(binding, target)
        end
      rescue NameError => e
        { error: "Not found: #{e.message}" }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def get_instance_method_source(binding, target)
        class_name, method_name = target.split("#", 2)
        klass = binding.eval(class_name)
        method = klass.instance_method(method_name.to_sym)

        extract_method_info(method, target)
      end

      def get_class_method_source(binding, target)
        class_name, method_name = target.split(".", 2)
        klass = binding.eval(class_name)
        method = klass.method(method_name.to_sym)

        extract_method_info(method, target)
      end

      def extract_method_info(method, target)
        location = method.source_location

        if location
          file, line = location
          source = read_source(file, line)
          {
            target: target,
            file: file,
            line: line,
            source: source,
            parameters: method.parameters.map { |type, name| "#{type}: #{name}" }
          }
        else
          {
            target: target,
            error: "Source not available (native or C extension method)",
            parameters: method.parameters.map { |type, name| "#{type}: #{name}" }
          }
        end
      end

      def get_class_info(binding, class_name)
        klass = binding.eval(class_name)

        {
          name: klass.name,
          type: klass.class.name,
          ancestors: klass.ancestors.first(10).map(&:to_s),
          instance_methods: klass.instance_methods(false).sort.first(30),
          class_methods: (klass.methods - Class.methods).sort.first(30),
          constants: klass.constants.first(20)
        }
      end

      def read_source(file, start_line)
        return nil unless File.exist?(file)

        lines = File.readlines(file)
        end_line = find_method_end(lines, start_line - 1)
        lines[(start_line - 1)..end_line].join
      rescue StandardError => e
        "(Failed to read source: #{e.message})"
      end

      def find_method_end(lines, start_index)
        return [start_index + MAX_SOURCE_LINES, lines.length - 1].min if start_index >= lines.length

        base_indent = lines[start_index][/^\s*/].length
        end_keywords = %w[end]

        (start_index + 1).upto([start_index + MAX_SOURCE_LINES, lines.length - 1].min) do |i|
          line = lines[i]
          next if line.strip.empty? || line.strip.start_with?("#")

          current_indent = line[/^\s*/].length
          if current_indent <= base_indent && end_keywords.any? { |kw| line.strip.start_with?(kw) }
            return i
          end
        end

        [start_index + MAX_SOURCE_LINES, lines.length - 1].min
      end
    end
  end
end
