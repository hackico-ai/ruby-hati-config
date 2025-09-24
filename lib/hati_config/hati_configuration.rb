# frozen_string_literal: true

# HatiConfig module provides functionality for managing configuration features.
#
# @example Using HatiConfiguration in a class
#   class MyApp
#     include HatiConfiguration
#
#     configure :settings do
#       config api_key: "default_key"
#       config max_retries: 3
#     end
#   end
#
#   MyApp.settings.api_key # => "default_key"
#   MyApp.settings.max_retries # => 3
#
# @example Configuring with a block
#   class AnotherApp
#     include HatiConfiguration
#
#     configure :app_settings do
#       config feature_enabled: true
#       config max_users: 100
#     end
#   end
#
#   AnotherApp.app_settings.feature_enabled # => true
#   AnotherApp.app_settings.max_users # => 100
module HatiConfiguration
  # Extends the base class with HatiConfig::Configuration and HatiConfig::Team module methods
  #
  # @param base [Class] The class extending this module
  # @return [void]
  def self.extended(base)
    base.extend(HatiConfig::Configuration)
    base.extend(HatiConfig::Team)
  end

  # Isolated module handles isolated configurations.
  #
  # This module allows for configuration inheritance while maintaining
  # isolation between parent and child configurations.
  #
  # @example Using Isolated configurations
  #   class ParentApp
  #     include HatiConfiguration::Isolated
  #
  #     configure :parent_settings do
  #       config timeout: 30
  #       config tries: 3
  #     end
  #   end
  #
  #   class ChildApp < ParentApp
  #     parent_settings do
  #       config tries: 4
  #     end
  #   end
  #
  #   ChildApp.parent_settings.timeout # => 30
  #   ChildApp.parent_settings.tries # => 4
  #   ParentApp.parent_settings.tries # => 3
  #
  # @example Configuring a child class
  #   class AnotherChildApp < ParentApp
  #     parent_settings do
  #       config timeout: 60
  #     end
  #   end
  #
  #   AnotherChildApp.parent_settings.timeout # => 60
  #   AnotherChildApp.parent_settings.tries # => 3
  module Local
    # Extends the base class with HatiConfig::Configuration and HatiConfig::Configuration::Isolated module methods
    #
    # @param base [Class] The class extending this module
    # @return [void]
    def self.extended(base)
      base.extend(HatiConfig::Configuration)
      base.extend(HatiConfig::Configuration::Local)
    end
  end
end
