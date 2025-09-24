# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ClassLevel::DeepNested' do
  let(:stng_values) do
    {
      one: 1,
      text: 'Lorem Ipsum',
      float_point: 4.2,
      none: nil
    }
  end

  context 'when using a deep nested namespace' do
    let(:configs) do
      support_dummy_module.tap do |dummy_module|
        dummy_module.configure :settings do
          configure :nested do
            configure :deep_nested do
              config :opt
              config.str :dsl_opt
              config.int :t_opt
              config :type_opt, type: :int
              config :cstm_type_opt, type: Integer
            end
          end
        end
      end
    end

    describe 'declared typed #config' do
      it 'has #opt config param' do
        configs.settings.config(opt: stng_values[:text])
        expect(configs.settings.opt).to eq(stng_values[:text])
      end

      it 'has #dsl_opt config param' do
        test_value = stng_values[:text]

        configs.settings.nested.deep_nested do
          config dsl_opt: test_value
        end

        expect(configs.settings.nested.deep_nested.dsl_opt).to eq(test_value)
      end

      it 'has #type_opt config param' do
        expect do
          configs.settings.nested.deep_nested.config(t_opt: stng_values[:text])
        end.to raise_error(HatiConfig::SettingTypeError)
      end

      it 'has #t_opt config param' do
        expect do
          configs.settings.nested.deep_nested.config(type_opt: stng_values[:text])
        end.to raise_error(HatiConfig::SettingTypeError)
      end

      it 'has #ctm_t_type_opt config param' do
        expect do
          configs.settings.nested.deep_nested.config(cstm_type_opt: stng_values[:text])
        end.to raise_error(HatiConfig::SettingTypeError)
      end
    end

    describe 'when extracting deep nested settings' do
      before do
        val = stng_values

        configs.settings.nested.deep_nested.config(opt: val[:text])
        configs.settings.nested.deep_nested do
          dsl_opt val[:text]
        end
        configs.settings.nested.deep_nested.config(t_opt: 10, type: :int)
        configs.settings.nested.deep_nested.config(type_opt: 10)
        configs.settings.nested.deep_nested.config(cstm_type_opt: 10)
      end

      it 'returns the type schema of the configuration' do
        expected_schema = { opt: :any, dsl_opt: :str, t_opt: :int, type_opt: :int, cstm_type_opt: Integer }

        expect(configs.settings.nested.deep_nested.type_schema).to eq(expected_schema)
      end

      it 'converts the configuration tree to a hash' do
        expected_hash = { opt: stng_values[:text], dsl_opt: stng_values[:text], t_opt: 10, type_opt: 10,
                          cstm_type_opt: 10 }

        expect(configs.settings.nested.deep_nested.to_h).to eq(expected_hash)
      end

      it 'converts the configuration tree to JSON' do
        expected_json = { opt: stng_values[:text], dsl_opt: stng_values[:text], t_opt: 10, type_opt: 10,
                          cstm_type_opt: 10 }.to_json

        expect(configs.settings.nested.deep_nested.to_json).to eq(expected_json)
      end
    end

    describe '#config' do
      let(:configs) do
        val = stng_values
        support_dummy_module.tap do |dummy_module|
          dummy_module.configure :settings do
            configure :nested do
              configure :deep_nested do
                config one: val[:one]
                config.str text: val[:text]
                config float_point: val[:float_point], type: :float
                config none: val[:none], type: NilClass
              end
            end
          end
        end
      end

      it 'has #one config parameter' do
        expect(configs.settings.nested.deep_nested.one).to eq(stng_values[:one])
      end

      it 'has #text config parameter' do
        expect(configs.settings.nested.deep_nested.text).to eq(stng_values[:text])
      end

      it 'has #float_point config parameter' do
        expect(configs.settings.nested.deep_nested.float_point).to eq(stng_values[:float_point])
      end

      it 'has #none config parameter' do
        expect(configs.settings.nested.deep_nested.none).to eq(stng_values[:none])
      end

      it 'returns the type schema of the configuration' do
        expected_schema = { nested: { deep_nested: { float_point: :float, none: NilClass, one: :any, text: :str } } }
        expect(configs.settings.type_schema).to eq(expected_schema)
      end

      it 'converts the configuration tree to a hash' do
        expected_hash = { nested: { deep_nested: { float_point: 4.2, none: nil, one: 1, text: 'Lorem Ipsum' } } }
        expect(configs.settings.to_h).to eq(expected_hash)
      end

      it 'converts the configuration tree to JSON' do
        expected_json = { nested: { deep_nested: { one: 1, text: 'Lorem Ipsum', float_point: 4.2,
                                                   none: nil } } }.to_json
        expect(configs.settings.to_json).to eq(expected_json)
      end
    end
  end
end
