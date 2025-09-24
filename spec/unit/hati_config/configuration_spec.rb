# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Configuration do
  describe '#configure' do
    let(:dummy_module) { Module.new { extend HatiConfig::Configuration } }

    context 'when using a block' do
      it 'configures settings correctly' do
        dummy_module.configure(:app_config) do
          config username: 'admin'
          config max_connections: 10, type: :int
        end

        expect(dummy_module.app_config.username).to eq('admin')
      end
    end

    context 'when loading from a hash' do
      it 'loads settings from a hash' do
        dummy_module.configure :app_config, hash: { username: 'admin', max_connections: 10 }

        aggregate_failures do
          expect(dummy_module.app_config.username).to eq('admin')
          expect(dummy_module.app_config.max_connections).to eq(10)
        end
      end
    end

    context 'when loading from a hash with schema' do
      let(:hash) { { username: 'admin', max_connections: 10 } }
      let(:schema) { { username: :str, max_connections: :int } }

      it 'loads settings from a hash with schema' do
        dummy_module.configure :app_config, hash: hash, schema: schema

        aggregate_failures do
          expect(dummy_module.app_config.username).to eq('admin')
          expect(dummy_module.app_config.max_connections).to eq(10)
        end
      end

      it 'raises SettingTypeError for invalid type' do
        hash[:max_connections] = '10'

        expect { dummy_module.configure(:app_config, hash: hash, schema: schema) }
          .to raise_error(HatiConfig::SettingTypeError)
      end
    end

    context 'when loading from JSON' do
      let(:json_data) { { username: 'admin', max_connections: 10 }.to_json }

      it 'loads settings from JSON' do
        dummy_module.configure(:app_config, json: json_data)

        aggregate_failures do
          expect(dummy_module.app_config.username).to eq('admin')
          expect(dummy_module.app_config.max_connections).to eq(10)
        end
      end
    end

    context 'when loading from YAML' do
      before do
        support_yaml_file_tempfile do |temp_file|
          dummy_module.configure(:app_config, yaml: temp_file.path)
        end
      end

      it 'loads settings from YAML' do
        aggregate_failures do
          expect(dummy_module.app_config.username).to eq('admin')
          expect(dummy_module.app_config.max_connections).to eq(10)
        end
      end
    end

    context 'when loading from remote sources' do
      let(:http_config) { { username: 'admin', max_connections: 10 } }
      let(:s3_config) { { database_url: 'postgres://localhost', pool_size: 5 } }
      let(:redis_config) { { feature_flags: { dark_mode: true } } }

      before do
        allow(HatiConfig::RemoteLoader).to receive(:from_http).and_return(http_config)
        allow(HatiConfig::RemoteLoader).to receive(:from_s3).and_return(s3_config)
        allow(HatiConfig::RemoteLoader).to receive(:from_redis).and_return(redis_config)
      end

      it 'loads settings from HTTP' do
        dummy_module.configure(:app_config, http: {
                                 url: 'https://config-server/config.json',
                                 headers: { 'Authorization' => 'Bearer token' }
                               })

        expect(dummy_module.app_config.username).to eq('admin')
        expect(dummy_module.app_config.max_connections).to eq(10)
      end

      it 'loads settings from S3' do
        dummy_module.configure(:app_config, s3: {
                                 bucket: 'my-configs',
                                 key: 'database.json',
                                 region: 'us-west-2'
                               })

        expect(dummy_module.app_config.database_url).to eq('postgres://localhost')
        expect(dummy_module.app_config.pool_size).to eq(5)
      end

      it 'loads settings from Redis' do
        dummy_module.configure(:app_config, redis: {
                                 host: 'redis.example.com',
                                 key: 'feature_flags'
                               })

        expect(dummy_module.app_config.feature_flags[:dark_mode]).to be true
      end
    end

    context 'when loading from invalid formats' do
      it 'raises LoadDataError for invalid JSON format' do
        expect do
          dummy_module.configure(:app_config, json: '{invalid_json}')
        end.to raise_error(HatiConfig::LoadDataError, 'Invalid JSON format')
      end

      it 'raises LoadDataError for non-existent YAML file' do
        expect do
          dummy_module.configure(:app_config, yaml: 'non_existent.yml')
        end.to raise_error(HatiConfig::LoadDataError, 'YAML file not found')
      end

      it 'raises LoadDataError for empty options' do
        expect do
          dummy_module.configure(:app_config, file: 'non_supported.txt')
        end.to raise_error(HatiConfig::LoadDataError, 'Invalid load source type')
      end
    end

    context 'when no options are provided' do
      it 'does not load any settings' do
        dummy_module.configure(:app_config)

        expect(dummy_module.respond_to?(:app_config)).to be true
      end
    end
  end
end
