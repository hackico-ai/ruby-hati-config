# frozen_string_literal: true

module HatiConfig
  # Environment module provides functionality for managing environment-specific configurations.
  module Environment
    # Defines environment-specific configuration overrides.
    #
    # @param env_name [Symbol] The name of the environment (e.g., :development, :staging, :production)
    # @yield The configuration block for the environment
    # @example
    #   environment :development do
    #     config api_url: 'http://localhost:3000'
    #     config debug: true
    #   end
    def environment(env_name, &block)
      return unless current_environment == env_name

      instance_eval(&block)
    end

    # Sets the current environment.
    #
    # @param env [Symbol] The environment to set
    # @example
    #   HatiConfig.environment = :production
    def self.current_environment=(env)
      @current_environment = env&.to_sym
    end

    # Gets the current environment.
    #
    # @return [Symbol] The current environment
    def self.current_environment
      @current_environment ||= begin
        env = if ENV['HATI_ENV']
                ENV['HATI_ENV']
              elsif ENV['RACK_ENV']
                ENV['RACK_ENV']
              elsif ENV['RAILS_ENV']
                ENV['RAILS_ENV']
              else
                'development'
              end
        env.to_sym
      end
    end

    # Gets the current environment.
    #
    # @return [Symbol] The current environment
    def current_environment
      Environment.current_environment
    end

    # Temporarily changes the environment for a block of code.
    #
    # @param env [Symbol] The environment to use
    # @yield The block to execute in the specified environment
    # @example
    #   HatiConfig.with_environment(:staging) do
    #     # Configuration will use staging environment here
    #   end
    def self.with_environment(env)
      original_env = current_environment
      self.current_environment = env
      yield
    ensure
      self.current_environment = original_env
    end

    # Checks if the current environment matches the given environment.
    #
    # @param env [Symbol] The environment to check
    # @return [Boolean] True if the current environment matches
    def environment?(env)
      current_environment == env.to_sym
    end

    # Checks if the current environment is development.
    #
    # @return [Boolean] True if in development environment
    def development?
      environment?(:development)
    end

    # Checks if the current environment is test.
    #
    # @return [Boolean] True if in test environment
    def test?
      environment?(:test)
    end

    # Checks if the current environment is staging.
    #
    # @return [Boolean] True if in staging environment
    def staging?
      environment?(:staging)
    end

    # Checks if the current environment is production.
    #
    # @return [Boolean] True if in production environment
    def production?
      environment?(:production)
    end
  end
end
