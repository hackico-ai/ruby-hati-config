# frozen_string_literal: true

require 'redis'
require 'connection_pool'
require 'json'

module HatiConfig
  # Cache module provides functionality for caching and refreshing configurations.
  module Cache
    # Module for handling numeric configuration attributes
    module NumericConfigurable
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def numeric_accessor(*names)
          names.each do |name|
            define_method(name) do |value = nil|
              if value.nil?
                instance_variable_get(:"@#{name}")
              else
                instance_variable_set(:"@#{name}", value)
                self
              end
            end
          end
        end
      end
    end

    # Defines caching behavior for configurations.
    #
    # @param adapter [Symbol] The cache adapter to use (:memory, :redis)
    # @param options [Hash] Options for the cache adapter
    # @yield The cache configuration block
    # @example
    #   cache do
    #     adapter :redis, url: "redis://cache.example.com:6379/0"
    #     ttl 300  # 5 minutes
    #     stale_while_revalidate true
    #   end
    def cache(&block)
      @cache_config = CacheConfig.new
      @cache_config.instance_eval(&block) if block_given?
      @cache_config
    end

    # Gets the cache configuration.
    #
    # @return [CacheConfig] The cache configuration
    def cache_config
      @cache_config ||= CacheConfig.new
    end

    # CacheConfig class handles cache configuration and behavior.
    class CacheConfig
      include NumericConfigurable

      attr_reader :adapter_type, :adapter_options

      numeric_accessor :ttl

      def refresh(&block)
        @refresh_config.instance_eval(&block) if block_given?
        @refresh_config
      end

      def stale_while_revalidate(enabled = nil)
        if enabled.nil?
          @stale_while_revalidate
        else
          @stale_while_revalidate = enabled
          self
        end
      end

      def initialize
        @adapter_type = :memory
        @adapter_options = {}
        @ttl = 300
        @stale_while_revalidate = false
        @refresh_config = RefreshConfig.new
        @adapter = nil
      end

      # Sets the cache adapter.
      #
      # @param type [Symbol] The adapter type (:memory, :redis)
      # @param options [Hash] Options for the adapter
      def adapter(*args, **kwargs)
        if args.empty? && kwargs.empty?
          @adapter ||= initialize_adapter
        else
          type = args[0]
          options = args[1] || kwargs
          @adapter_type = type
          @adapter_options = options
          @adapter = nil
          self
        end
      end

      attr_writer :adapter

      private

      def initialize_adapter
        case adapter_type
        when :memory
          MemoryAdapter.new
        when :redis
          RedisAdapter.new(adapter_options)
        else
          raise ArgumentError, "Unknown cache adapter: #{adapter_type}"
        end
      end

      # Gets a value from the cache.
      #
      # @param key [String] The cache key
      # @return [Object, nil] The cached value or nil if not found
      def get(key)
        adapter.get(key)
      end

      # Sets a value in the cache.
      #
      # @param key [String] The cache key
      # @param value [Object] The value to cache
      # @param ttl [Integer, nil] Optional TTL override
      def set(key, value, ttl = nil)
        adapter.set(key, value, ttl || @ttl)
      end

      # Deletes a value from the cache.
      #
      # @param key [String] The cache key
      def delete(key)
        adapter.delete(key)
      end
    end

    # RefreshConfig class handles refresh configuration and behavior.
    class RefreshConfig
      include NumericConfigurable

      attr_reader :interval, :jitter, :backoff_config

      numeric_accessor :interval, :jitter

      def initialize
        @interval = 60
        @jitter = 0
        @backoff_config = BackoffConfig.new
      end

      # Configures backoff behavior.
      #
      # @yield The backoff configuration block
      def backoff(&block)
        @backoff_config.instance_eval(&block) if block_given?
        @backoff_config
      end

      # Gets the next refresh time.
      #
      # @return [Time] The next refresh time
      def next_refresh_time
        jitter_amount = jitter.positive? ? rand(0.0..jitter) : 0
        Time.now + interval + jitter_amount
      end
    end

    # BackoffConfig class handles backoff configuration and behavior.
    class BackoffConfig
      include NumericConfigurable

      attr_reader :initial, :multiplier, :max

      numeric_accessor :initial, :multiplier, :max

      def initialize
        @initial = 1
        @multiplier = 2
        @max = 300
      end

      # Gets the backoff time for a given attempt.
      #
      # @param attempt [Integer] The attempt number
      # @return [Integer] The backoff time in seconds
      def backoff_time(attempt)
        time = initial * (multiplier**(attempt - 1))
        [time, max].min
      end
    end

    # MemoryAdapter class provides in-memory caching.
    class MemoryAdapter
      def initialize
        @store = {}
        @expiry = {}
      end

      # Gets a value from the cache.
      #
      # @param key [String] The cache key
      # @return [Object, nil] The cached value or nil if not found/expired
      def get(key)
        return nil if expired?(key)

        @store[key]
      end

      # Sets a value in the cache.
      #
      # @param key [String] The cache key
      # @param value [Object] The value to cache
      # @param ttl [Integer] The TTL in seconds
      def set(key, value, ttl)
        @store[key] = value
        @expiry[key] = Time.now + ttl if ttl
      end

      # Deletes a value from the cache.
      #
      # @param key [String] The cache key
      def delete(key)
        @store.delete(key)
        @expiry.delete(key)
      end

      private

      def expired?(key)
        expiry = @expiry[key]
        expiry && Time.now >= expiry
      end
    end

    # RedisAdapter class provides Redis-based caching.
    class RedisAdapter
      def initialize(options)
        @pool = ConnectionPool.new(size: 5, timeout: 5) do
          Redis.new(options)
        end
      end

      # Gets a value from the cache.
      #
      # @param key [String] The cache key
      # @return [Object, nil] The cached value or nil if not found
      def get(key)
        @pool.with do |redis|
          value = redis.get(key)
          value ? Marshal.load(value) : nil
        end
      rescue TypeError, ArgumentError
        nil
      end

      # Sets a value in the cache.
      #
      # @param key [String] The cache key
      # @param value [Object] The value to cache
      # @param ttl [Integer] The TTL in seconds
      def set(key, value, ttl)
        @pool.with do |redis|
          redis.setex(key, ttl, Marshal.dump(value))
        end
      end

      # Deletes a value from the cache.
      #
      # @param key [String] The cache key
      def delete(key)
        @pool.with do |redis|
          redis.del(key)
        end
      end
    end
  end
end
