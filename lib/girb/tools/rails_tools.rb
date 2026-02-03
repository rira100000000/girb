# frozen_string_literal: true

require_relative "base"

module Girb
  module Tools
    class RailsProjectInfo < Base
      class << self
        def available?
          defined?(Rails)
        end

        def description
          "Get Rails project information: current directory (Rails.root), environment, Ruby/Rails versions, database config, and list of all defined models. Use this to find project path or list models."
        end

        def parameters
          {
            type: "object",
            properties: {},
            required: []
          }
        end
      end

      def execute(binding)
        info = {
          root: Rails.root.to_s,
          environment: Rails.env,
          ruby_version: RUBY_VERSION
        }

        # Rails version
        info[:rails_version] = Rails.version if Rails.respond_to?(:version)

        # Database info
        if defined?(ActiveRecord::Base)
          begin
            config = ActiveRecord::Base.connection_db_config
            info[:database] = {
              adapter: config.adapter,
              database: config.database
            }
          rescue StandardError
            # DB not connected
          end
        end

        # Defined models
        if defined?(ActiveRecord::Base)
          begin
            Rails.application.eager_load! unless Rails.application.config.eager_load
            info[:models] = ActiveRecord::Base.descendants.map(&:name).sort
          rescue StandardError
            # Unable to load models
          end
        end

        info
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end
    end

    class RailsModelInfo < Base
      class << self
        def available?
          defined?(ActiveRecord::Base)
        end

        def description
          "Get Rails ActiveRecord model information including associations, validations, callbacks, and scopes."
        end

        def parameters
          {
            type: "object",
            properties: {
              model_name: {
                type: "string",
                description: "The model class name (e.g., 'User', 'Order', 'Product')"
              }
            },
            required: ["model_name"]
          }
        end
      end

      def execute(binding, model_name:)
        klass = binding.eval(model_name)

        unless klass < ActiveRecord::Base
          return { error: "#{model_name} is not an ActiveRecord model" }
        end

        {
          model: model_name,
          table_name: klass.table_name,
          primary_key: klass.primary_key,
          columns: get_columns(klass),
          associations: get_associations(klass),
          validations: get_validations(klass),
          callbacks: get_callbacks(klass),
          scopes: get_scopes(klass)
        }
      rescue NameError => e
        { error: "Model not found: #{e.message}" }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      private

      def get_columns(klass)
        klass.columns.map do |col|
          {
            name: col.name,
            type: col.type,
            null: col.null,
            default: col.default
          }
        end
      rescue StandardError
        []
      end

      def get_associations(klass)
        klass.reflect_on_all_associations.map do |assoc|
          info = {
            name: assoc.name,
            type: assoc.macro,
            class_name: assoc.class_name
          }

          # オプションがあれば追加
          %i[dependent through source foreign_key].each do |opt|
            value = assoc.options[opt]
            info[opt] = value if value
          end

          info
        end
      rescue StandardError
        []
      end

      def get_validations(klass)
        klass.validators.map do |validator|
          {
            attributes: validator.attributes,
            kind: validator.kind,
            options: validator.options.reject { |k, _| %i[if unless].include?(k) }
          }
        end
      rescue StandardError
        []
      end

      def get_callbacks(klass)
        callback_types = %i[
          before_validation after_validation
          before_save after_save around_save
          before_create after_create around_create
          before_update after_update around_update
          before_destroy after_destroy around_destroy
        ]

        callback_types.to_h do |callback_type|
          callbacks = begin
            klass.send("_#{callback_type}_callbacks").map do |cb|
              { filter: cb.filter.to_s, kind: cb.kind }
            end
          rescue StandardError
            []
          end
          [callback_type, callbacks]
        end.reject { |_, v| v.empty? }
      end

      def get_scopes(klass)
        # Rails doesn't expose scope names directly, but we can check for scope methods
        # that are defined on the class but not on ActiveRecord::Base
        base_methods = ActiveRecord::Base.methods
        scope_candidates = (klass.methods - base_methods).select do |method_name|
          # スコープは通常、ActiveRecord::Relationを返す
          begin
            klass.respond_to?(method_name) &&
              klass.method(method_name).arity <= 0
          rescue StandardError
            false
          end
        end
        scope_candidates.sort.first(20)
      rescue StandardError
        []
      end
    end
  end
end
