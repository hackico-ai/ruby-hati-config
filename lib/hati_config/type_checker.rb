# frozen_string_literal: true

# HatiConfig module provides functionality for managing HatiConfig features.
module HatiConfig
  # This class is responsible for type checking in the Hati configuration.
  class TypeChecker
    class << self
      # Calls the appropriate validation method based on the type.
      #
      # @param value [Object] The value to validate.
      # @param type [Symbol, Array<Symbol, Class>, Class] The type(s) to validate against.
      # @return [Boolean] True if the value matches the type, false otherwise.
      # @raise [TypeCheckerError] if the type is unsupported or not defined.
      #
      # @example
      #   TypeChecker.call(1, type: :int) # => true
      #   TypeChecker.call(1, type: :numeric) # => true
      #   TypeChecker.call("hello", type: [:str, Integer]) # => true
      #   TypeChecker.call(CustomClass.new, type: CustomClass) # => true
      def call(value, type:, **_opts)
        case type
        when Symbol
          base_type(value, fetch_type(type))
        when Array
          if type.length == 1 && type.first.is_a?(Symbol)
            # Array type validation (e.g., [:string] for array of strings)
            return false unless value.is_a?(Array)

            value.all? { |v| call(v, type: type.first) }
          else
            # Union type validation (e.g., [:string, Integer] for string or integer)
            one_of(value, type)
          end
        else
          custom_type?(value, type)
        end
      end

      # Validates if value matches the base type.
      #
      # @param value [Object] the value to validate
      # @param type [Class] the type to validate against
      # @return [Boolean] true if the value matches the base type
      # @raise [TypeCheckerError] if the type is unsupported or not defined.
      #
      # @example
      #   TypeChecker.base_type(1, Integer) # => true
      #   TypeChecker.base_type(1, [:int, :float, :big_decimal]) # => true
      def base_type(value, type)
        type = fetch_type(type) if type.is_a?(Symbol)

        return type.call(value) if type.is_a?(Proc)

        type.is_a?(Array) ? one_of(value, type) : value.is_a?(type)
      end

      # Checks if value matches any type in the array.
      #
      # @param value [Object] the value to validate
      # @param array_type [Array<Symbol, Class>] the array of types to validate against
      # @return [Boolean] true if the value matches any type in the array
      #
      # @example
      #   TypeChecker.one_of(1, [Integer, :str]) # => true
      #   TypeChecker.one_of("hello", [Integer, String, :sym]) # => true
      #   TypeChecker.one_of(nil, [:null, Integer, String]) # => true
      #   TypeChecker.one_of(1.5, [:int, :float, :big_decimal]) # => true
      def one_of(value, array_type)
        array_type.any? { |type| type.is_a?(Symbol) ? base_type(value, type) : custom_type?(value, type) }
      end

      # Validates if value is of the specified custom type.
      #
      # @param value [Object] the value to validate
      # @param type [Class] the custom type to validate against
      # @return [Boolean] true if the value is of the specified custom type
      #
      # @example
      #   TypeChecker.custom_type(1, Integer) # => true
      #   TypeChecker.custom_type(CustomClass.new, CustomClass) # => true
      def custom_type?(value, type)
        value.is_a?(type)
      end

      # Fetches the basic type from the type map.
      #
      # @param type [Symbol] the type to fetch
      # @return [Class] the corresponding basic type
      # @raise [TypeCheckerError] if the type does not exist in TYPE_MAP
      #
      # @example
      #   TypeChecker.fetch_type(:int) # => Integer
      #   TypeChecker.fetch_type(:null) # => NilClass
      #   TypeChecker.fetch_type(:bool) # => [:truthy, :falsy]
      def fetch_type(type)
        basic_type = TypeMap.get(type)
        raise HatiConfig::TypeCheckerError, type unless basic_type

        basic_type
      end
    end
  end
end
