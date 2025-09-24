# frozen_string_literal: true

# HatiConfig module provides functionality for managing HatiConfig features.
module HatiConfig
  # This module handles configuration trees and loading data from various sources.
  module Configuration
    # Isolated module provides methods for handling isolated configurations.
    module Local
      # Configures an isolated config tree and tracks it
      #
      # @param config_tree_name [Symbol] The name of the configuration tree
      # @param opts [Hash] Options for configuration
      # @yield The configuration block
      # @return [self]
      #
      # @example
      #   configure :isolated_settings do
      #     config api_url: "https://api.example.com"
      #   end
      #
      #   # Example of accessing the configuration
      #   puts MyApp.isolated_settings.api_url # => "https://api.example.com"
      def configure(config_tree_name, opts = {}, &block)
        super

        @isolated_configs ||= []
        @isolated_configs << config_tree_name

        self
      end

      # Inherits isolated configurations to the base class
      #
      # @param base [Class] The inheriting class
      #
      # @example
      #   class ChildClass < ParentClass
      #     # Automatically inherits isolated configurations
      #   end
      #
      #   # Example of accessing inherited configurations
      #   puts ChildClass.parent_settings.timeout # => 30
      def inherited(base)
        super

        @isolated_configs.each do |parent_config|
          hash = __send__(parent_config).to_h
          schema = __send__(parent_config).type_schema
          lock_schema = __send__(parent_config).lock_schema

          base.configure parent_config, hash: hash, schema: schema, lock_schema: lock_schema
        end
      end
    end

    # Creates a class-level method for the configuration tree.
    #
    # This method allows you to define a configuration tree using a block
    # or load configuration data from a hash, JSON, or YAML file.
    #
    # @param config_tree_name [Symbol, String] The name of the configuration method to be defined.
    # @param opts [Hash] Optional options for loading configuration data.
    # @option opts [Hash] :hash A hash containing configuration data.
    # @option opts [String] :json A JSON string containing configuration data.
    # @option opts [String] :yaml A file path to a YAML file containing configuration data.
    # @option opts [Hash] :schema A hash representing the type schema for the configuration.
    # @yield [Setting] A block that builds the configuration tree.
    #
    # @example Configuring with a block
    #   configure :app_config do
    #     config :username, value: "admin"
    #     config :max_connections, type: :int, value: 10
    #   end
    #
    # @example Loading from a hash
    #   configure :app_config, hash: { username: "admin", max_connections: 10 }
    #
    # @example Loading from a JSON string
    #   configure :app_config, json: '{"username": "admin", "max_connections": 10}'
    #
    # @example Loading from a YAML file
    #   configure :app_config, yaml: 'config/settings.yml'
    #
    # @example Loading with a schema
    #   configure :app_config, hash: { name: "admin", policy: "allow" }, schema: { name: :str, policy: :str }
    def configure(config_tree_name, opts = {}, &block)
      settings = block ? HatiConfig::Setting.new(&block) : HatiConfig::Setting.new

      load_configs = load_data(opts) unless opts.empty?
      settings.load_from_hash(load_configs, schema: opts[:schema], lock_schema: opts[:lock_schema]) if load_configs

      define_singleton_method(config_tree_name) do |&tree_block|
        tree_block ? settings.instance_eval(&tree_block) : settings
      end
    end

    module_function

    # Loads configuration data from various sources based on the provided options.
    #
    # @param opts [Hash] Optional options for loading configuration data.
    # @option opts [Hash] :hash A hash containing configuration data.
    # @option opts [String] :json A JSON string containing configuration data.
    # @option opts [String] :yaml A file path to a YAML file containing configuration data.
    # @return [Hash] The loaded configuration data.
    # @raise [LoadDataError] If no valid data is found.
    #
    # @example Loading from a hash
    #   load_data(hash: { key: "value" })
    #
    # @example Loading from a JSON string
    #   load_data(json: '{"key": "value"}')
    #
    # @example Loading from a YAML file
    #   load_data(yaml: 'config/settings.yml')
    def load_data(opts = {})
      data = if opts[:hash]
               opts[:hash]
             elsif opts[:json]
               JSON.parse(opts[:json])
             elsif opts[:yaml]
               YAML.load_file(opts[:yaml])
             elsif opts[:http]
               RemoteLoader.from_http(**opts[:http])
             elsif opts[:s3]
               RemoteLoader.from_s3(**opts[:s3])
             elsif opts[:redis]
               RemoteLoader.from_redis(**opts[:redis])
             end

      raise HatiConfig::LoadDataError, 'Invalid load source type' unless data

      data
    rescue JSON::ParserError
      raise HatiConfig::LoadDataError, 'Invalid JSON format'
    rescue Errno::ENOENT
      raise HatiConfig::LoadDataError, 'YAML file not found'
    end
  end
end
