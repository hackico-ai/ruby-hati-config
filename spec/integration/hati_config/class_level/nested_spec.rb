# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ClassLevel::Nested' do
  let(:stng_values) do
    {
      one: 1,
      text: 'Lorem Ipsum',
      float_point: 4.2,
      none: nil
    }
  end

  context 'when nested namespace' do
    let(:configs) do
      support_dummy_module.tap do |dummy_module|
        dummy_module.configure :settings do
          configure :nested do
            config :opt
            config.str :dsl_opt
            config.int :t_opt
            config :type_opt, type: :int
            config :cstm_type_opt, type: Integer
          end
        end
      end
    end

    describe 'declared typed #config' do
      it 'has #opt config param' do
        configs.settings.config opt: stng_values[:text]
        expect(configs.settings.opt).to eq(stng_values[:text])
      end

      it 'has #dsl_opt config param' do
        test_value = stng_values[:text]

        configs.settings.nested do
          config dsl_opt: test_value
        end

        expect(configs.settings.nested.dsl_opt).to eq(test_value)
      end

      it 'has #type_opt config param' do
        expect { configs.settings.nested.config(t_opt: stng_values[:text]) }.to raise_error(HatiConfig::SettingTypeError)
      end

      it 'has #t_opt config param' do
        expect do
          configs.settings.nested.config(type_opt: stng_values[:text])
        end.to raise_error(HatiConfig::SettingTypeError)
      end

      it 'has #cstm_type_opt config param' do
        expect do
          configs.settings.nested.config cstm_type_opt: stng_values[:text]
        end.to raise_error(HatiConfig::SettingTypeError)
      end
    end

    context 'when retrieving configuration details' do
      before do
        val = stng_values

        configs.tap do |dummy_module|
          dummy_module.settings.nested do
            config opt: val[:text]
            dsl_opt val[:text]
            config t_opt: val[:int]
            config type_opt: val[:int]
            config cstm_type_opt: val[:int]
          end
        end
      end

      let(:expected_structure) do
        {
          nested: {
            opt: stng_values[:text],
            dsl_opt: stng_values[:text],
            t_opt: stng_values[:int],
            type_opt: stng_values[:int],
            cstm_type_opt: stng_values[:int]
          }
        }
      end

      it 'returns the type schema of the configuration' do
        expected_schema = { nested: { opt: :any, dsl_opt: :str, t_opt: :int, type_opt: :int, cstm_type_opt: Integer } }

        expect(configs.settings.type_schema).to eq(expected_schema)
      end

      it 'converts the configuration tree to a hash' do
        expect(configs.settings.to_h).to eq(expected_structure)
      end

      it 'converts the configuration tree to JSON' do
        expect(configs.settings.to_json).to eq(expected_structure.to_json)
      end

      it 'converts the configuration tree to YAML' do
        expect(configs.settings.to_yaml).to eq(expected_structure.to_yaml)
      end
    end

    describe '#config' do
      let(:configs) do
        val = stng_values

        support_dummy_module.tap do |dummy_module|
          dummy_module.configure :settings do
            configure :nested do
              config one: val[:one]
              config.str text: val[:text]
              config float_point: val[:float_point], type: :float
              config none: val[:none], type: NilClass
            end
          end
        end
      end

      let(:expected_structure) do
        {
          nested: {
            one: stng_values[:one],
            text: stng_values[:text],
            float_point: stng_values[:float_point],
            none: stng_values[:none]
          }
        }
      end

      it 'has #one configuration parameter' do
        expect(configs.settings.nested.one).to eq(stng_values[:one])
      end

      it 'has #text configuration parameter' do
        expect(configs.settings.nested.text).to eq(stng_values[:text])
      end

      it 'has #float_point configuration parameter' do
        expect(configs.settings.nested.float_point).to eq(stng_values[:float_point])
      end

      it 'has #none configuration parameter' do
        expect(configs.settings.nested.none).to eq(stng_values[:none])
      end

      it 'returns the type schema of the configuration' do
        expected_schema = { nested: { one: :any, text: :str, float_point: :float, none: NilClass } }
        expect(configs.settings.type_schema).to eq(expected_schema)
      end

      it 'converts the configuration tree to a hash' do
        expect(configs.settings.to_h).to eq(expected_structure)
      end

      it 'converts the configuration tree to JSON' do
        expect(configs.settings.to_json).to eq(expected_structure.to_json)
      end

      it 'converts the configuration tree to YAML' do
        expect(configs.settings.to_yaml).to eq(expected_structure.to_yaml)
      end
    end
  end
end
