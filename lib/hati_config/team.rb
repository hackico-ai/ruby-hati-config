# frozen_string_literal: true

module HatiConfig
  # Team module provides functionality for managing team-specific configurations.
  module Team
    # Defines team-specific configuration namespace.
    #
    # @param team_name [Symbol] The name of the team (e.g., :frontend, :backend, :mobile)
    # @yield The configuration block for the team
    # @example
    #   team :frontend do
    #     configure :settings do
    #       config api_endpoint: '/api/v1'
    #       config cache_ttl: 300
    #     end
    #   end
    def team(team_name, &block)
      team_module = Module.new do
        extend HatiConfig::Configuration
        extend HatiConfig::Environment
      end

      const_name = team_name.to_s.capitalize
      const_set(const_name, team_module)
      team_module.instance_eval(&block) if block_given?

      # Define method for accessing team module
      singleton_class.class_eval do
        define_method(team_name) { const_get(const_name) }
      end

      team_module
    end

    # Gets a list of all defined teams.
    #
    # @return [Array<Symbol>] The list of team names
    def teams
      constants.select { |c| const_get(c).is_a?(Module) && const_get(c).respond_to?(:configure) }
    end

    # Gets a specific team's configuration module.
    #
    # @param team_name [Symbol] The name of the team
    # @return [Module] The team's configuration module
    # @raise [NameError] If the team does not exist
    def [](team_name)
      const_get(team_name.to_s.capitalize)
    end

    # Checks if a team exists.
    #
    # @param team_name [Symbol] The name of the team
    # @return [Boolean] True if the team exists
    def team?(team_name)
      const_defined?(team_name.to_s.capitalize)
    end

    # Removes a team's configuration.
    #
    # @param team_name [Symbol] The name of the team
    # @return [Boolean] True if the team was removed
    def remove_team?(team_name)
      const_name = team_name.to_s.capitalize
      return false unless const_defined?(const_name)

      remove_const(const_name)
      true
    end

    # Temporarily switches to a team's configuration context.
    #
    # @param team_name [Symbol] The name of the team
    # @yield The block to execute in the team's context
    # @example
    #   with_team(:frontend) do
    #     # Configuration will use frontend team's context here
    #   end
    def with_team(team_name)
      raise NameError, "Team '#{team_name}' does not exist" unless team?(team_name)

      yield self[team_name]
    end
  end
end
