# frozen_string_literal: true

require "spec_helper"

RSpec.describe "ClassLevel::Local::Configs" do
  before do
    support_dummy_class("BaseConfig")

    BaseConfig.configure :app do
      config param_a: 1, type: :int
      config.str param_b: "2"

      configure :nested do
        config.int param_a: 1
        config.str param_b: "2"

        configure :deep_nested do
          config param_a: 1
          config param_b: "2", type: :str
        end
      end
    end

    stub_const("InheritedConfig", Class.new(BaseConfig))
  end

  context "when inherit configirations" do
    it "inherit configurations" do
      aggregate_failures do
        expect(BaseConfig.app.param_a).to eq(1)
        expect(InheritedConfig.app.param_b).to eq("2")
      end
    end

    it "modify child configuration without modify parent" do
      InheritedConfig.app { param_b "two" }
      aggregate_failures do
        expect(BaseConfig.app.param_a).to eq(1)
        expect(InheritedConfig.app.param_b).to eq("two")
      end
    end

    it "expect error when setting param_a to non-integer value" do
      InheritedConfig.app { param_a "switched_type", type: :str }

      aggregate_failures do
        expect { InheritedConfig.app { param_a 1 } }.to raise_error(HatiConfig::SettingTypeError)
        expect { InheritedConfig.app { param_b 1 } }.to raise_error(HatiConfig::SettingTypeError)
      end
    end
  end

  context "when inherit nested configurations" do
    it "inherit nested configurations" do
      aggregate_failures do
        expect(BaseConfig.app.nested.param_a).to eq(1)
        expect(InheritedConfig.app.nested.param_b).to eq("2")
      end
    end

    it "modify deeply nested child configuration without modify parent" do
      InheritedConfig.app.nested { param_b "nested_two" }

      aggregate_failures do
        expect(BaseConfig.app.nested.param_a).to eq(1)
        expect(InheritedConfig.app.nested.param_b).to eq("nested_two")
      end
    end

    it "expect error when setting param_a to non-integer value" do
      InheritedConfig.app.nested { param_a "switched_type", type: :str }

      aggregate_failures do
        expect { InheritedConfig.app.nested { param_a 1 } }.to raise_error(HatiConfig::SettingTypeError)
        expect { InheritedConfig.app.nested { param_b 1 } }.to raise_error(HatiConfig::SettingTypeError)
      end
    end
  end

  context "when inherit deeply nested configurations" do
    it "inherit deeply nested configurations" do
      aggregate_failures do
        expect(BaseConfig.app.nested.deep_nested.param_a).to eq(1)
        expect(InheritedConfig.app.nested.deep_nested.param_b).to eq("2")
      end
    end

    it "modify deeply nested child configuration without modify parent" do
      InheritedConfig.app.nested.deep_nested { param_b "deep_nested_two", type: :str }

      aggregate_failures do
        expect(BaseConfig.app.nested.deep_nested.param_a).to eq(1)
        expect(InheritedConfig.app.nested.deep_nested.param_b).to eq("deep_nested_two")
      end
    end

    it "expect error when setting param_a to non-integer value" do
      InheritedConfig.app.nested.deep_nested { param_a "switched_type", type: :str }

      aggregate_failures do
        expect { InheritedConfig.app.nested.deep_nested { param_a 1 } }.to raise_error(HatiConfig::SettingTypeError)
        expect { InheritedConfig.app.nested.deep_nested { param_b 1 } }.to raise_error(HatiConfig::SettingTypeError)
      end
    end
  end
end
