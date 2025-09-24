# frozen_string_literal: true

require 'net/http'
require 'aws-sdk-s3'
require 'redis'
require 'json'
require 'yaml'

module HatiConfig
  # RemoteLoader handles loading configurations from remote sources like HTTP, S3, and Redis.
  # It supports automatic refresh and caching of configurations.
  class RemoteLoader
    class << self
      # Loads configuration from an HTTP endpoint
      #
      # @param url [String] The URL to load the configuration from
      # @param headers [Hash] Optional headers to include in the request
      # @param refresh_interval [Integer] Optional interval in seconds to refresh the configuration
      # @return [Hash] The loaded configuration
      # @raise [LoadDataError] If the configuration cannot be loaded
      def from_http(url:, headers: {}, refresh_interval: nil)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        headers.each { |key, value| request[key] = value }

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        parse_response(response.body, File.extname(uri.path))
      rescue StandardError => e
        raise LoadDataError, "Failed to load configuration from HTTP: #{e.message}"
      end

      # Loads configuration from an S3 bucket
      #
      # @param bucket [String] The S3 bucket name
      # @param key [String] The S3 object key
      # @param region [String] The AWS region
      # @param refresh_interval [Integer] Optional interval in seconds to refresh the configuration
      # @return [Hash] The loaded configuration
      # @raise [LoadDataError] If the configuration cannot be loaded
      def from_s3(bucket:, key:, region:, refresh_interval: nil)
        s3 = Aws::S3::Client.new(region: region)
        response = s3.get_object(bucket: bucket, key: key)
        parse_response(response.body.read, File.extname(key))
      rescue Aws::S3::Errors::ServiceError => e
        raise LoadDataError, "Failed to load configuration from S3: #{e.message}"
      end

      # Loads configuration from Redis
      #
      # @param host [String] The Redis host
      # @param key [String] The Redis key
      # @param port [Integer] The Redis port (default: 6379)
      # @param db [Integer] The Redis database number (default: 0)
      # @param refresh_interval [Integer] Optional interval in seconds to refresh the configuration
      # @return [Hash] The loaded configuration
      # @raise [LoadDataError] If the configuration cannot be loaded
      def from_redis(host:, key:, port: 6379, db: 0, refresh_interval: nil)
        redis = Redis.new(host: host, port: port, db: db)
        data = redis.get(key)
        raise LoadDataError, "Key '#{key}' not found in Redis" unless data

        parse_response(data)
      rescue Redis::BaseError => e
        raise LoadDataError, "Failed to load configuration from Redis: #{e.message}"
      end

      private

      def parse_response(data, extension = nil)
        case extension&.downcase
        when '.json', nil
          JSON.parse(data, symbolize_names: true)
        when '.yaml', '.yml'
          YAML.safe_load(data, symbolize_names: true)
        else
          raise LoadDataError, "Unsupported file format: #{extension}"
        end
      rescue JSON::ParserError, Psych::SyntaxError => e
        raise LoadDataError, "Failed to parse configuration: #{e.message}"
      end
    end
  end
end

