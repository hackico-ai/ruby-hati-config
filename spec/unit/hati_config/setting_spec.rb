# frozen_string_literal: true

require "spec_helper"

RSpec.describe HatiConfig::Setting do
  let(:setting) { described_class.new }

  describe "#initialize" do
    let(:app_settings) do
      described_class.new do
        config username: "admin"
        config max_connections: 10, type: :int
      end
    end

    it "initializes with a block and configures settings" do
      aggregate_failures do
        expect(app_settings.username).to eq("admin")
        expect(app_settings.max_connections).to eq(10)
        expect(app_settings.type_schema).to include(username: :any, max_connections: :int)
      end
    end

    it "does not raise an error when no block is given" do
      expect { setting }.not_to raise_error
    end
  end

  describe "#configure" do
    before do
      setting.configure :new_node do
        config key: "value"
      end
    end

    it "configures a new node in the configuration tree" do
      aggregate_failures do
        expect(setting.new_node).to be_a(described_class)
        expect(setting.new_node.key).to eq("value")
      end
    end
  end

  describe "#config" do
    it "raises an error for invalid type" do
      expect { setting.config(key: "value", type: :int) }.to raise_error(HatiConfig::SettingTypeError)
    end

    it "stores valid configuration" do
      setting.config(key: "value")

      expect(setting.key).to eq("value")
    end
  end

  describe "#to_h" do
    it "converts the configuration tree to a hash" do
      setting.config(key: "value")

      expect(setting.to_h).to eq({ key: "value" })
    end
  end

  describe "#to_yaml" do
    it "converts the configuration tree to YAML" do
      setting.config(key: "value")

      expect(setting.to_yaml).to include("key: value")
    end
  end

  describe "#to_json" do
    it "converts the configuration tree to JSON" do
      setting.config(key: "value")

      expect(setting.to_json).to include('"key":"value"')
    end
  end

  describe "#type_schema" do
    it "returns the type schema of the configuration" do
      setting.config(key1: "value1", type: :str)
      setting.config(key2: 42, type: :int)
      expected_schema = { key1: :str, key2: :int }

      expect(setting.type_schema).to eq(expected_schema)
    end

    it "returns an empty hash when no configurations are set" do
      expect(setting.type_schema).to eq({})
    end

    it "handles nested settings" do
      setting.configure :nested do
        config key3: "value3", type: :str
      end

      expected_schema = { key3: :str }

      expect(setting.nested.type_schema).to eq(expected_schema)
    end
  end

  describe "hash-like access" do
    before do
      setting.config(key1: "value1")
      setting.config(key2: 42)
      setting.configure :nested do
        config key3: "value3"
      end
    end

    describe "#[]" do
      it "accesses configuration values using string keys" do
        expect(setting["key1"]).to eq("value1")
        expect(setting["key2"]).to eq(42)
      end

      it "accesses configuration values using symbol keys" do
        expect(setting[:key1]).to eq("value1")
        expect(setting[:key2]).to eq(42)
      end

      it "raises NoMethodError for non-existent keys" do
        expect { setting[:non_existent] }.to raise_error(NoMethodError)
      end

      it "returns Setting instance for nested configurations" do
        expect(setting[:nested]).to be_a(described_class)
        expect(setting[:nested][:key3]).to eq("value3")
      end
    end

    describe "#[]=" do
      it "sets configuration values using string keys" do
        setting["key4"] = "new value"
        expect(setting.key4).to eq("new value")
      end

      it "sets configuration values using symbol keys" do
        setting[:key5] = "another value"
        expect(setting.key5).to eq("another value")
      end

      it "updates existing configuration values" do
        setting[:key1] = "updated value"
        expect(setting.key1).to eq("updated value")
      end
    end
  end
end
