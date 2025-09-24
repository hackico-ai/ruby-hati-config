# frozen_string_literal: true

require "spec_helper"

RSpec.describe HatiConfig::TypeChecker do
  let(:cstm_stub) { Class.new }

  describe ".call" do
    it "validates if value matches the type" do
      expect(described_class.call(1, type: [:str, Integer])).to be(true)
    end

    it "raises an error for nonexistent types" do
      expect { described_class.call(1, type: :unsupported) }.to raise_error(HatiConfig::TypeCheckerError)
    end
  end

  describe ".base_type" do
    it "validates Integer type" do
      expect(described_class.base_type(1, Integer)).to be(true)
    end

    it "validates built-in types" do
      aggregate_failures "with one of valid types" do
        ["1", 1].each { |value| expect(described_class.base_type(value, [Integer, String])).to be(true) }
      end
    end

    it "validates array of types" do
      expect(described_class.base_type(1, [Integer, :str, cstm_stub])).to be(true)
    end

    it "returns false for invalid types" do
      expect(described_class.base_type("string", Integer)).to be(false)
    end

    it "raises an error for nonexistent types" do
      expect { described_class.base_type(1, :nonexistent) }.to raise_error(HatiConfig::TypeCheckerError)
    end

    it "handles nil values" do
      expect(described_class.base_type(nil, Integer)).to be(false)
    end

    it "handles custom class types" do
      custom_instance = cstm_stub.new
      aggregate_failures "validating custom class types" do
        expect(described_class.base_type(custom_instance, cstm_stub)).to be(true)
        expect(described_class.base_type(custom_instance, String)).to be(false)
      end
    end
  end

  describe ".custom_type" do
    it "validates if value matches the custom type" do
      expect(described_class.custom_type(cstm_stub.new, cstm_stub)).to be(true)
    end

    it "validates if value does not match the custom type" do
      expect(described_class.custom_type(1, cstm_stub)).to be(false)
    end
  end

  describe ".one_of" do
    it "validates if value matches any type in the array" do
      expect(described_class.one_of(1, [Integer, :str, cstm_stub])).to be(true)
    end

    it "validates if value does not match any type in the array" do
      expect(described_class.one_of("string", [Integer, :int, cstm_stub])).to be(false)
    end
  end

  describe ".fetch_type" do
    it "fetches the corresponding type if it exists" do
      expect(described_class.fetch_type(:int)).to eq(Integer)
    end

    it "raises an error for nonexistent types" do
      expect { described_class.fetch_type(:nonexistent) }.to raise_error(HatiConfig::TypeCheckerError)
    end
  end
end
