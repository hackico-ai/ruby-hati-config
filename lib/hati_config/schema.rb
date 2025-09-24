# frozen_string_literal: true

module HatiConfig
  # Schema module provides functionality for managing configuration schemas and versioning.
  module Schema
    # Defines a schema for configuration validation.
    #
    # @param version [String] The schema version (e.g., "1.0", "2.0")
    # @yield The schema definition block
    # @example
    #   schema version: "1.0" do
    #     required :database_url, type: :string
    #     optional :pool_size, type: :integer, default: 5
    #     deprecated :old_setting, since: "1.0", remove_in: "2.0"
    #   end
    def schema(version: "1.0", &block)
      @schema_version = version
      @schema_definition = SchemaDefinition.new(version)
      @schema_definition.instance_eval(&block) if block_given?
      @schema_definition
    end

    # Gets the current schema version.
    #
    # @return [String] The current schema version
    def schema_version
      @schema_version || "1.0"
    end

    # Gets the schema definition.
    #
    # @return [SchemaDefinition] The schema definition
    def schema_definition
      @schema_definition ||= SchemaDefinition.new(schema_version)
    end

    # Defines a migration between schema versions.
    #
    # @param versions [Hash] The from and to versions (e.g., "1.0" => "2.0")
    # @yield [config] The migration block
    # @example
    #   migration "1.0" => "2.0" do |config|
    #     config.replica_urls = [config.delete(:backup_url)].compact
    #   end
    def migration(versions, &block)
      schema_definition.add_migration(versions, block)
    end

    # SchemaDefinition class handles schema validation and migration.
    class SchemaDefinition
      attr_reader :version, :required_fields, :optional_fields, :deprecated_fields, :migrations

      def initialize(version)
        @version = version
        @required_fields = {}
        @optional_fields = {}
        @deprecated_fields = {}
        @migrations = {}
      end

      # Defines a required field in the schema.
      #
      # @param name [Symbol] The field name
      # @param type [Symbol, Class] The field type
      # @param since [String] The version since this field is required
      def required(name, type:, since: version)
        @required_fields[name] = { type: type, since: since }
      end

      # Defines an optional field in the schema.
      #
      # @param name [Symbol] The field name
      # @param type [Symbol, Class] The field type
      # @param default [Object] The default value
      # @param since [String] The version since this field is available
      def optional(name, type:, default: nil, since: version)
        @optional_fields[name] = { type: type, default: default, since: since }
      end

      # Marks a field as deprecated.
      #
      # @param name [Symbol] The field name
      # @param since [String] The version since this field is deprecated
      # @param remove_in [String] The version when this field will be removed
      def deprecated(name, since:, remove_in:)
        @deprecated_fields[name] = { since: since, remove_in: remove_in }
      end

      # Adds a migration between versions.
      #
      # @param from_version [String] The source version
      # @param to_version [String] The target version
      # @param block [Proc] The migration block
          def add_migration(from_version, to_version = nil, block = nil, &implicit_block)
            if block.nil? && to_version.respond_to?(:call)
              # Handle the case where to_version is the block
              block = to_version
              if from_version.is_a?(Hash)
                from_version, to_version = from_version.first
              else
                from_version, to_version = from_version.to_s.gsub(/['"{}]/, "").split("=>").map(&:strip)
              end
            end

            migration_block = block || implicit_block
            raise MigrationError, "Invalid migration format" unless from_version && to_version && migration_block

            key = migration_key(from_version, to_version)
            @migrations[key] = migration_block
          end

          def migration(versions, &block)
            if versions.is_a?(Hash)
              from_version, to_version = versions.first
            else
              from_version, to_version = versions.to_s.gsub(/['"{}]/, "").split("=>").map(&:strip)
            end
            raise MigrationError, "Invalid migration format" unless from_version && to_version

            add_migration(from_version, to_version, nil, &block)
          end

      # Validates configuration data against the schema.
      #
      # @param data [Hash] The configuration data to validate
      # @param current_version [String] The current schema version
      # @raise [ValidationError] If validation fails
      def validate(data, current_version = version)
        validate_required_fields(data, current_version)
        validate_deprecated_fields(data, current_version)
        validate_types(data)
      end

      # Migrates configuration data from one version to another.
      #
      # @param data [Hash] The configuration data to migrate
      # @param from_version [String] The source version
      # @param to_version [String] The target version
      # @return [Hash] The migrated configuration data
      def migrate(data, from_version, to_version)
        key = migration_key(from_version, to_version)
        migration = migrations[key]
        raise MigrationError, "No migration path from #{from_version} to #{to_version}" unless migration

        data = data.dup
        migration.call(data)
        data
      end

      private

      def migration_key(from_version, to_version)
        "#{from_version}-#{to_version}"
      end

      private

      def validate_required_fields(data, current_version)
        required_fields.each do |name, field|
          next if field[:since] > current_version
          next if data.key?(name)

          raise ValidationError, "Missing required field: #{name}"
        end
      end

      def validate_deprecated_fields(data, current_version)
        deprecated_fields.each do |name, field|
          next unless data.key?(name)
          next unless field[:since] <= current_version

          if field[:remove_in] <= current_version
            raise ValidationError, "Field #{name} was removed in version #{field[:remove_in]}"
          end

          warn "Field #{name} is deprecated since version #{field[:since]} and will be removed in #{field[:remove_in]}"
        end
      end

      def validate_types(data)
        all_fields = required_fields.merge(optional_fields)
        data.each do |name, value|
          field = all_fields[name]
          next unless field

          type = field[:type]
          next if TypeChecker.call(value, type: type)

          raise ValidationError, "Invalid type for field #{name}: expected #{type}, got #{value.class}"
        end
      end
    end

    # Error raised when schema validation fails.
    class ValidationError < StandardError; end

    # Error raised when schema migration fails.
    class MigrationError < StandardError; end
  end
end
