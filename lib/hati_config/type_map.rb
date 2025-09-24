# frozen_string_literal: true

require 'bigdecimal'
require 'date'

# HatiConfig module provides functionality for managing HatiConfig features.
module HatiConfig
  # A class that maps type symbols to their corresponding Ruby classes and provides
  # predefined collections of type symbols for various categories.
  #
  # This class allows retrieval of Ruby classes based on type symbols and provides
  # methods to access collections of specific type symbols such as booleans, numerics,
  # and chronological types.
  class TypeMap
    TYPE_MAP = {
      # base types
      int: Integer,
      integer: Integer,
      str: String,
      string: String,
      sym: Symbol,
      null: NilClass,
      true_class: TrueClass,
      false_class: FalseClass,
      # data structures
      hash: Hash,
      array: Array,
      # numeric types
      big_decimal: BigDecimal,
      float: Float,
      complex: Complex,
      rational: Rational,
      # time types
      date: Date,
      date_time: DateTime,
      time: Time,
      # any type
      any: Object,
      # composite types
      bool: %i[true_class false_class],
      numeric: %i[int float big_decimal],
      kernel_num: %i[int float big_decimal complex rational],
      chrono: %i[date date_time time]
    }.freeze

    # Retrieves the Ruby class associated with a given type symbol.
    #
    # @param type [Symbol] The type symbol to look up. Must be one of the keys in TYPE_MAP.
    # @return [Class, nil] The corresponding Ruby class or nil if the type symbol is not found.
    #
    # @example
    #   TypeMap.get(:int) # => Integer
    #   TypeMap.get(:str) # => String
    #   TypeMap.get(:unknown) # => nil
    def self.get(type)
      TYPE_MAP[type]
    end

    # Returns an array of all type symbols defined in TYPE_MAP.
    #
    # @return [Array<Symbol>] An array containing all keys from TYPE_MAP.
    #
    # @example
    #   TypeMap.list_types # => [:int, :str, :sym, :null, :true_class, :false_class,
    #                          :hash, :array, :big_decimal, :float, :complex,
    #                          :rational, :date, :date_time, :time, :any,
    #                          :bool, :numeric, :kernel_num, :chrono]
    def self.list_types
      TYPE_MAP.keys
    end
  end
end
