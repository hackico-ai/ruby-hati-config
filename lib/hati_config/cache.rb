# frozen_string_literal: true

require "redis"
require "connection_pool"

module HatiConfig
  # Cache module provides functionality for caching and refreshing configurations.
  module Cache
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
      attr_reader :adapter_type, :adapter_options, :ttl, :stale_while_revalidate

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
          @adapter ||= begin
            case adapter_type
            when :memory
              MemoryAdapter.new
            when :redis
              RedisAdapter.new(adapter_options)
            else
              raise ArgumentError, "Unknown cache adapter: #{adapter_type}"
            end
          end
        else
          type = args[0]
          options = args[1] || kwargs
          @adapter_type = type
          @adapter_options = options
          @adapter = nil
          self
        end
      end

      def adapter_type
        @adapter_type
      end

      def adapter_options
        @adapter_options
      end

      def adapter=(adapter)
        @adapter = adapter
      end

      def get_adapter
        @adapter ||= begin
          case adapter_type
          when :memory
            MemoryAdapter.new
          when :redis
            RedisAdapter.new(adapter_options)
          else
            raise ArgumentError, "Unknown cache adapter: #{adapter_type}"
          end
        end
      end

      # Sets the cache TTL.
      #
      # @param seconds [Integer] The TTL in seconds
      def ttl(seconds = nil)
        if seconds.nil?
          @ttl
        else
          @ttl = seconds
        end
      end

      # Enables/disables stale-while-revalidate behavior.
      #
      # @param enabled [Boolean] Whether to enable stale-while-revalidate
      def stale_while_revalidate(enabled = nil)
        if enabled.nil?
          @stale_while_revalidate
        else
          @stale_while_revalidate = enabled
          self
        end
      end

      # Configures refresh behavior.
      #
      # @yield The refresh configuration block
      def refresh(&block)
        @refresh_config.instance_eval(&block) if block_given?
        @refresh_config
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
      attr_reader :interval, :jitter, :backoff_config

      def initialize
        @interval = 60
        @jitter = 0
        @backoff_config = BackoffConfig.new
      end

      # Sets the refresh interval.
      #
      # @param seconds [Integer] The refresh interval in seconds
      def interval(seconds = nil)
        if seconds.nil?
          @interval
        else
          @interval = seconds
        end
      end

      # Sets the jitter amount.
      #
      # @param seconds [Integer] The jitter in seconds
      def jitter(seconds = nil)
        if seconds.nil?
          @jitter
        else
          @jitter = seconds
        end
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
        jitter_amount = jitter > 0 ? rand(0.0..jitter) : 0
        Time.now + interval + jitter_amount
      end
    end

    # BackoffConfig class handles backoff configuration and behavior.
    class BackoffConfig
      attr_reader :initial, :multiplier, :max

      def initialize
        @initial = 1
        @multiplier = 2
        @max = 300
      end

      # Sets the initial backoff time.
      #
      # @param seconds [Integer] The initial backoff in seconds
      def initial(seconds = nil)
        if seconds.nil?
          @initial
        else
          @initial = seconds
        end
      end

      # Sets the backoff multiplier.
      #
      # @param value [Integer] The backoff multiplier
      def multiplier(value = nil)
        if value.nil?
          @multiplier
        else
          @multiplier = value
        end
      end

      # Sets the maximum backoff time.
      #
      # @param seconds [Integer] The maximum backoff in seconds
      def max(seconds = nil)
        if seconds.nil?
          @max
        else
          @max = seconds
        end
      end

      # Gets the backoff time for a given attempt.
      #
      # @param attempt [Integer] The attempt number
      # @return [Integer] The backoff time in seconds
      def backoff_time(attempt)
        time = initial * (multiplier ** (attempt - 1))
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
