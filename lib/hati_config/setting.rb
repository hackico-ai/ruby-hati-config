# frozen_string_literal: true

require "yaml"
require "json"

# HatiConfig module provides functionality for managing HatiConfig features.
module HatiConfig
  # rubocop:disable Metrics/ClassLength

  # Setting class provides a configuration tree structure for managing settings.
  #
  # This class allows for dynamic configuration management, enabling
  # the loading of settings from hashes, YAML, or JSON formats.
  #
  # @example Basic usage
  #   settings = Setting.new do
  #     config(:key1, value: "example")
  #     config(:key2, type: :int)
  #   end
  #
  class Setting
    extend HatiConfig::Environment
    include HatiConfig::Environment
    extend HatiConfig::Schema
    extend HatiConfig::Cache
    extend HatiConfig::Encryption

    # Dynamically define methods for each type in TypeMap.
    #
    # @!method int(value)
    #   Sets an integer configuration value.
    #   @param value [Integer] The integer value to set.
    #
    # @!method string(value)
    #   Sets a string configuration value.
    #   @param value [String] The string value to set.
    #
    # ... (other type methods)
    HatiConfig::TypeMap.list_types.each do |type|
      define_method(type.downcase) do |stng, lock = nil|
        params = { type: type }
        params[:lock] = lock if lock.nil?

        config(stng, **params)
      end
    end

    # Initializes a new Setting instance.
    #
    # @yield [self] Configures the instance upon creation if a block is given.
    def initialize(&block)
      @config_tree = {}
      @schema = {}
      @immutable_schema = {}
      @encrypted_tree = {}

      if self.class.encryption_config.key_provider
        self.class.encryption do
          key_provider :env
        end
      end

      instance_eval(&block) if block_given?
    end

    # Loads configuration from a hash with an optional schema.
    #
    # @param data [Hash] The hash containing configuration data.
    # @param schema [Hash] Optional schema for type validation.
    # @raise [NoMethodError] If a method corresponding to a key is not defined.
    # @raise [SettingTypeError] If a value doesn't match the specified type in the schema.
    #
    # @example Loading from a hash with type validation
    #   settings.load_from_hash({ name: "admin", max_connections: 10 }, schema: { name: :str, max_connections: :int })
    def load_from_hash(data, schema: {}, lock_schema: {}, encrypted_fields: {})
      data.each do |key, value|
        key = key.to_sym
        type = schema[key] if schema
        lock = lock_schema[key] if lock_schema
        encrypted = encrypted_fields[key] if encrypted_fields

        if value.is_a?(Hash)
          configure(key) do
            load_from_hash(value,
                           schema: schema.is_a?(Hash) ? schema[key] : {},
                           lock_schema: lock_schema.is_a?(Hash) ? lock_schema[key] : {},
                           encrypted_fields: encrypted_fields.is_a?(Hash) ? encrypted_fields[key] : {})
          end
        elsif value.is_a?(Setting)
          configure(key) do
            load_from_hash(value.to_h, schema: schema[key], lock_schema: lock_schema[key],
                                       encrypted_fields: encrypted_fields[key])
          end
        else
          config(key => value, type: type, lock: lock, encrypted: encrypted)
        end
      end
    end

    # Configures a node of the configuration tree.
    #
    # @param node [Symbol, String] The name of the config node key.
    # @yield [Setting] A block that configures the new node.
    #
    # @example Configuring a new node
    #   settings.configure(:database) do
    #     config(:host, value: "localhost")
    #     config(:port, value: 5432)
    #   end
    def configure(node, &block)
      if config_tree[node]
        config_tree[node].instance_eval(&block)
      else
        create_new_node(node, &block)
      end
    end

    # Configures a setting with a given name and type.
    #
    # @param setting [Symbol, Hash, nil] The name of the setting or a hash of settings.
    # @param type [Symbol, nil] The expected type of the setting.
    # @param opt [Hash] Additional options for configuration.
    # @return [self] The current instance for method chaining.
    # @raise [SettingTypeError] If the value does not match the expected type.
    #
    # @example Configuring a setting
    #   settings.config(max_connections: 10, type: :int)
    def config(setting = nil, type: nil, lock: nil, encrypted: false, **opt)
      return self if !setting && opt.empty?

      # If setting is a symbol/string and we have keyword options, merge them
      if (setting.is_a?(Symbol) || setting.is_a?(String)) && !opt.empty?
        raw_stngs = opt.merge(setting => opt[:value])
        raw_stngs.delete(:value)
      else
        raw_stngs = setting || opt
      end
      stngs = extract_setting_info(raw_stngs)

      stng_lock = determine_lock(stngs, lock)
      stng_type = determine_type(stngs, type)
      stng_encrypted = determine_encrypted(stngs, encrypted)

      if stng_encrypted
        value = stngs[:value]
        if value.nil? && config_tree[stngs[:name]]
          value = config_tree[stngs[:name]]
          value = self.class.encryption_config.decrypt(value) if @encrypted_tree[stngs[:name]]
        end

        if value.is_a?(HatiConfig::Setting)
          # Handle nested settings
          value.instance_eval(&block) if block_given?
        elsif !value.nil?
          # If we're setting a new value or updating an existing one
          raise SettingTypeError.new("string (encrypted values must be strings)", value) unless value.is_a?(String)

          stngs[:value] = self.class.encryption_config.encrypt(value)
          @encrypted_tree[stngs[:name]] = true
          # If we're just marking an existing value as encrypted
        elsif config_tree[stngs[:name]]
          value = config_tree[stngs[:name]]
          raise SettingTypeError.new("string (encrypted values must be strings)", value) unless value.is_a?(String)

          stngs[:value] = self.class.encryption_config.encrypt(value)
          @encrypted_tree[stngs[:name]] = true
        end
      end

      validate_and_set_configuration(stngs, stng_lock, stng_type, stng_encrypted)
      self
    end

    # Returns the type schema of the configuration.
    #
    # @return [Hash] A hash representing the type schema.
    # @example Retrieving the type schema
    #   schema = settings.type_schema
    def type_schema
      {}.tap do |hsh|
        config_tree.each do |k, v|
          v.is_a?(HatiConfig::Setting) ? (hsh[k] = v.type_schema) : hsh.merge!(schema)
        end
      end
    end

    def lock_schema
      {}.tap do |hsh|
        config_tree.each do |k, v|
          v.is_a?(HatiConfig::Setting) ? (hsh[k] = v.lock_schema) : hsh.merge!(immutable_schema)
        end
      end
    end

    # Converts the configuration tree into a hash.
    #
    # @return [Hash] The config tree as a hash.
    # @example Converting to hash
    #   hash = settings.to_h
    def to_h
      {}.tap do |hsh|
        config_tree.each do |k, v|
          hsh[k] = if v.is_a?(HatiConfig::Setting)
                     v.to_h
                   else
                     get_value(k)
                   end
        end
      end
    end

    # Converts the configuration tree into YAML format.
    #
    # @param dump [String, nil] Optional file path to dump the YAML.
    # @return [String, nil] The YAML string or nil if dumped to a file.
    # @example Converting to YAML
    #   yaml_string = settings.to_yaml
    #   settings.to_yaml(dump: "config.yml") # Dumps to a file
    def to_yaml(dump: nil)
      yaml = to_h.to_yaml
      dump ? File.write(dump, yaml) : yaml
    end

    # Converts the configuration tree into JSON format.
    #
    # @return [String] The JSON representation of the configuration tree.
    # @example Converting to JSON
    #   json_string = settings.to_json
    def to_json(*_args)
      to_h.to_json
    end

    # Provides hash-like access to configuration values
    #
    # @param key [Symbol, String] The key to access
    # @return [Object] The value associated with the key
    def [](key)
      key = key.to_sym if key.is_a?(String)
      return get_value(key) if config_tree.key?(key)

      raise NoMethodError, "undefined method `[]' with key #{key} for #{self.class}"
    end

    # Sets a configuration value using hash-like syntax
    #
    # @param key [Symbol, String] The key to set
    # @param value [Object] The value to set
    def []=(key, value)
      key = key.to_sym if key.is_a?(String)
      config(key => value)
    end

    protected

    # @return [Hash] The schema of configuration types.
    attr_reader :schema, :immutable_schema

    private

    # @return [Hash] The tree structure of configuration settings.
    attr_reader :config_tree

    # Creates a new node in the configuration tree.
    #
    # @param node [Symbol] The name of the node to create.
    # @yield [Setting] A block to configure the new setting.
    # @return [Setting] The newly created setting node.
    def create_new_node(node, &block)
      new_node = HatiConfig::Setting.new
      if self.class.encryption_config.key_provider
        new_node.class.encryption do
          key_provider :env
        end
      end
      new_node.instance_eval(&block) if block_given?
      config_tree[node] = new_node
      define_node_methods(node)
      new_node
    end

    # Defines singleton methods for the given node.
    #
    # @param node [Symbol] The name of the node to define methods for.
    def define_node_methods(node)
      define_singleton_method(node) do |*_args, &node_block|
        if node_block
          config_tree[node].instance_eval(&node_block)
        else
          config_tree[node]
        end
      end
    end

    # Extracts the setting information from the provided input.
    #
    # @param stngs [Symbol, Hash] The setting name or a hash containing the setting name and value.
    # @return [Hash] A hash containing the setting name and its corresponding value.
    def extract_setting_info(stngs)
      val = nil
      lock = nil
      encrypted = nil

      if stngs.is_a?(Symbol)
        name = stngs
      elsif stngs.is_a?(Hash)
        lock = stngs.delete(:lock)
        encrypted = stngs.delete(:encrypted)
        name, val = stngs.to_a.first
      end

      { name: name, value: val, lock: lock, encrypted: encrypted }
    end

    def handle_value(key, value, type, lock, encrypted = false)
      validate_mutable!(key, lock) if lock
      validate_setting!(value, type) if type

      config(key => value, type: type, lock: lock, encrypted: encrypted)
      self
    end

    def get_value(key)
      value = config_tree[key]
      return value if value.is_a?(HatiConfig::Setting)
      return self.class.encryption_config.decrypt(value) if @encrypted_tree[key]

      value
    end

    # Validates the setting value against the expected type.
    #
    # @param stng_val [Object] The value of the setting to validate.
    # @param stng_type [Symbol] The expected type of the setting.
    # @raise [SettingTypeError] If the setting value does not match the expected type.
    def validate_setting!(stng_val, stng_type)
      is_valid = HatiConfig::TypeChecker.call(stng_val, type: stng_type)
      raise HatiConfig::SettingTypeError.new(stng_type, stng_val) unless !stng_val || is_valid
    end

    def validate_mutable!(name, stng_lock)
      raise "<#{name}> setting is immutable" if stng_lock
    end

    # Sets the configuration for a given setting name, value, and type.
    #
    # @param stng_name [Symbol] The name of the setting to configure.
    # @param stng_val [Object] The value to assign to the setting.
    # @param stng_type [Symbol] The type of the setting.
    def set_configuration(stng_name:, stng_val:, stng_type:, stng_lock:)
      schema[stng_name] = stng_type
      config_tree[stng_name] = stng_val
      immutable_schema[stng_name] = stng_lock

      return if respond_to?(stng_name)

      define_singleton_method(stng_name) do |value = nil, type: nil, lock: nil, encrypted: false|
        return get_value(stng_name) unless value || encrypted

        if encrypted && !value.nil? && !value.is_a?(String)
          raise SettingTypeError.new("string (encrypted values must be strings)", value)
        end

        config(**{ stng_name => value, type: type, lock: lock, encrypted: encrypted })
      end
    end

    def determine_lock(stngs, lock)
      lock.nil? ? stngs[:lock] : lock
    end

    def determine_type(stngs, type)
      type || schema[stngs[:name]] || :any
    end

    def determine_encrypted(stngs, encrypted)
      encrypted.nil? ? stngs[:encrypted] : encrypted
    end

    def validate_and_set_configuration(stngs, stng_lock, stng_type, stng_encrypted)
      validate_mutable!(stngs[:name], stng_lock) if stngs[:value] && config_tree[stngs[:name]] && !stng_lock
      validate_setting!(stngs[:value], stng_type)

      set_configuration(stng_name: stngs[:name], stng_val: stngs[:value], stng_type: stng_type, stng_lock: stng_lock)
      @encrypted_tree[stngs[:name]] = stng_encrypted if stng_encrypted
      self
    end
  end
  # rubocop:enable Metrics/ClassLength
end
