# frozen_string_literal: true

require 'openssl'
require 'base64'

module HatiConfig
  # Encryption module provides methods for encrypting and decrypting sensitive configuration values.
  module Encryption
    # Custom error class for encryption-related errors.
    class EncryptionError < StandardError; end

    # Defines encryption configuration for a class or module.
    #
    # @yield [encryption_config] A block to configure encryption settings.
    # @return [EncryptionConfig] The encryption configuration instance.
    def encryption(&block)
      @encryption_config ||= EncryptionConfig.new
      @encryption_config.instance_eval(&block) if block_given?
      @encryption_config
    end

    # Gets the encryption configuration.
    #
    # @return [EncryptionConfig] The encryption configuration
    def encryption_config
      @encryption_config ||= EncryptionConfig.new
    end

    # EncryptionConfig class handles encryption configuration and behavior.
    class EncryptionConfig
      attr_reader :key_provider, :algorithm, :key_size, :mode, :key_provider_type, :key_provider_options

      def initialize
        @key_provider = nil
        @key_provider_type = nil
        @key_provider_options = {}
        @algorithm = 'aes'
        @key_size = 256
        @mode = 'gcm'
      end

      # Sets the key provider.
      #
      # @param provider [Symbol] The key provider type (:env, :file, :aws_kms)
      # @param options [Hash] Options for the key provider
      def key_provider(provider = nil, options = {})
        if provider.nil?
          @key_provider
        else
          @key_provider_type = provider
          @key_provider_options = options
          @key_provider = KeyProvider.create(provider, options)
          self
        end
      end

      # Sets the encryption algorithm.
      #
      # @param value [String] The encryption algorithm (e.g., "aes")
      def algorithm(value = nil)
        if value.nil?
          @algorithm
        else
          @algorithm = value
          self
        end
      end

      # Sets the key size.
      #
      # @param value [Integer] The key size in bits (e.g., 256)
      def key_size(value = nil)
        if value.nil?
          @key_size
        else
          @key_size = value
          self
        end
      end

      # Sets the encryption mode.
      #
      # @param value [String] The encryption mode (e.g., "gcm")
      def mode(value = nil)
        if value.nil?
          @mode
        else
          @mode = value
          self
        end
      end

      # Encrypts a value.
      #
      # @param value [String] The value to encrypt
      # @return [String] The encrypted value in Base64 format
      # @raise [EncryptionError] If encryption fails
      def encrypt(value)
        raise EncryptionError, 'No key provider configured' unless @key_provider

        begin
          cipher = OpenSSL::Cipher.new("#{@algorithm}-#{@key_size}-#{@mode}")
          cipher.encrypt
          cipher.key = @key_provider.key

          if @mode == 'gcm'
            cipher.auth_data = ''
            iv = cipher.random_iv
            cipher.iv = iv
            ciphertext = cipher.update(value.to_s) + cipher.final
            auth_tag = cipher.auth_tag

            # Format: Base64(IV + Auth Tag + Ciphertext)
            Base64.strict_encode64(iv + auth_tag + ciphertext)
          else
            iv = cipher.random_iv
            cipher.iv = iv
            ciphertext = cipher.update(value.to_s) + cipher.final

            # Format: Base64(IV + Ciphertext)
            Base64.strict_encode64(iv + ciphertext)
          end
        rescue OpenSSL::Cipher::CipherError => e
          raise EncryptionError, "Encryption failed: #{e.message}"
        end
      end

      # Decrypts a value.
      #
      # @param encrypted_value [String] The encrypted value in Base64 format
      # @return [String] The decrypted value
      # @raise [EncryptionError] If decryption fails
      def decrypt(encrypted_value)
        raise EncryptionError, 'No key provider configured' unless @key_provider
        return nil if encrypted_value.nil?

        begin
          data = Base64.strict_decode64(encrypted_value)
          cipher = OpenSSL::Cipher.new("#{@algorithm}-#{@key_size}-#{@mode}")
          cipher.decrypt
          cipher.key = @key_provider.key

          if @mode == 'gcm'
            iv = data[0, 12] # GCM uses 12-byte IV
            auth_tag = data[12, 16] # GCM uses 16-byte auth tag
            ciphertext = data[28..]

            cipher.iv = iv
            cipher.auth_tag = auth_tag
            cipher.auth_data = ''

          else
            iv = data[0, 16] # Other modes typically use 16-byte IV
            ciphertext = data[16..]

            cipher.iv = iv
          end
          cipher.update(ciphertext) + cipher.final
        rescue OpenSSL::Cipher::CipherError => e
          raise EncryptionError, "Decryption failed: #{e.message}"
        rescue ArgumentError => e
          raise EncryptionError, "Invalid encrypted value: #{e.message}"
        end
      end
    end

    # KeyProvider class hierarchy for handling encryption keys.
    class KeyProvider
      def self.create(type, options = {})
        case type
        when :env
          EnvKeyProvider.new(options)
        when :file
          FileKeyProvider.new(options)
        when :aws_kms
          AwsKmsKeyProvider.new(options)
        else
          raise EncryptionError, "Unknown key provider: #{type}"
        end
      end

      def key
        raise NotImplementedError, 'Subclasses must implement #key'
      end
    end

    # EnvKeyProvider gets the encryption key from an environment variable.
    class EnvKeyProvider < KeyProvider
      def initialize(options = {})
        super()
        @env_var = options[:env_var] || 'HATI_CONFIG_ENCRYPTION_KEY'
      end

      def key
        key = ENV.fetch(@env_var, nil)
        raise EncryptionError, "Encryption key not found in environment variable #{@env_var}" unless key

        key
      end
    end

    # FileKeyProvider gets the encryption key from a file.
    class FileKeyProvider < KeyProvider
      def initialize(options = {})
        super()
        @file_path = options[:file_path]
        raise EncryptionError, 'File path not provided' unless @file_path
      end

      def key
        raise EncryptionError, "Key file not found: #{@file_path}" unless File.exist?(@file_path)

        File.read(@file_path).strip
      rescue SystemCallError => e
        raise EncryptionError, "Failed to read key file: #{e.message}"
      end
    end

    # AwsKmsKeyProvider gets the encryption key from AWS KMS.
    class AwsKmsKeyProvider < KeyProvider
      def initialize(options = {})
        super()
        require 'aws-sdk-kms'
        @key_id = options[:key_id]
        @region = options[:region]
        @client = nil
        raise EncryptionError, 'KMS key ID not provided' unless @key_id
      end

      def key
        @key ||= begin
          client = Aws::KMS::Client.new(region: @region)
          response = client.generate_data_key(
            key_id: @key_id,
            key_spec: 'AES_256'
          )
          response.plaintext
        rescue Aws::KMS::Errors::ServiceError => e
          raise EncryptionError, "Failed to get key from KMS: #{e.message}"
        end
      end
    end
  end
end
