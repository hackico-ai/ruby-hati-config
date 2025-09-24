# frozen_string_literal: true

# Dummy module provides utility methods for creating dummy classes and modules
# for testing purposes with HatiConfiguration.
module Dummy
  # Creates a dummy class with the specified name and extends it with
  # HatiConfiguration::Isolated.
  #
  # @param name [String] The name of the class to be created.
  # @example Creating a dummy class
  #   support_dummy_class("TestClass")
  #   expect(TestClass).to be_a(Class)
  def support_dummy_class(name)
    stub_const(name, Class.new { extend HatiConfiguration::Local })
  end

  # Creates a dummy module that extends HatiConfiguration.
  #
  # @return [Module] A new module that extends HatiConfiguration.
  # @example Creating a dummy module
  #   dummy_module = support_dummy_module
  #   expect(dummy_module).to respond_to(:configure)
  def support_dummy_module
    Module.new { extend HatiConfiguration }
  end
end
