# frozen_string_literal: true

require "tempfile"

# YamlFile module provides utility methods for handling YAML files in tests.
module YamlFile
  # Creates a temporary YAML file with predefined content and yields the file to a block.
  #
  # This method generates a temporary file named "config.yml" containing a YAML representation
  # of a hash with default settings. The block provided to this method will receive the temporary
  # file as an argument for further processing.
  #
  # @yieldparam temp_file [Tempfile] The temporary file containing the YAML data.
  # @yieldreturn [void] Returns nothing.
  #
  # @example Using the support_yaml_file_tempfile method
  #   support_yaml_file_tempfile do |file|
  #     # Perform operations with the temporary YAML file
  #     puts file.read
  #   end
  def support_yaml_file_tempfile
    Tempfile.create(["config", ".yml"]) do |temp_file|
      temp_file.write({ username: "admin", max_connections: 10 }.to_yaml)
      temp_file.rewind

      yield temp_file
    end
  end
end
