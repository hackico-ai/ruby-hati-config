# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe HatiConfig::RemoteLoader do
  describe '.from_http' do
    let(:config_url) { 'https://config-server.example.com/config.json' }
    let(:config_data) { { api_key: 'secret', timeout: 30 } }
    let(:headers) { { 'Authorization' => 'Bearer token' } }

    before do
      stub_request(:get, config_url)
        .with(headers: headers)
        .to_return(body: config_data.to_json, status: 200)
    end

    it 'loads configuration from HTTP endpoint' do
      config = described_class.from_http(url: config_url, headers: headers)
      expect(config).to eq(config_data)
    end

    context 'when the request fails' do
      before do
        stub_request(:get, config_url)
          .to_return(status: 404)
      end

      it 'raises LoadDataError' do
        expect do
          described_class.from_http(url: config_url)
        end.to raise_error(HatiConfig::LoadDataError)
      end
    end

    context 'with YAML format' do
      let(:yaml_url) { 'https://config-server.example.com/config.yml' }
      let(:yaml_data) { "api_key: secret\ntimeout: 30\n" }

      before do
        stub_request(:get, yaml_url)
          .to_return(body: yaml_data, status: 200)
      end

      it 'loads YAML configuration' do
        config = described_class.from_http(url: yaml_url)
        expect(config).to eq(config_data)
      end
    end
  end

  describe '.from_s3' do
    let(:s3_client) { instance_double(Aws::S3::Client) }
    let(:s3_response) { instance_double(Aws::S3::Types::GetObjectOutput) }
    let(:config_data) { { database_url: 'postgres://localhost', pool_size: 5 } }

    before do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_response).to receive(:body).and_return(StringIO.new(config_data.to_json))
      allow(s3_client).to receive(:get_object).and_return(s3_response)
    end

    it 'loads configuration from S3' do
      config = described_class.from_s3(
        bucket: 'my-configs',
        key: 'database.json',
        region: 'us-west-2'
      )
      expect(config).to eq(config_data)
    end

    context 'when S3 request fails' do
      before do
        allow(s3_client).to receive(:get_object)
          .and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'Not found'))
      end

      it 'raises LoadDataError' do
        expect do
          described_class.from_s3(
            bucket: 'my-configs',
            key: 'database.json',
            region: 'us-west-2'
          )
        end.to raise_error(HatiConfig::LoadDataError)
      end
    end
  end

  describe '.from_redis' do
    let(:redis_client) { instance_double(Redis) }
    let(:config_data) { { feature_flags: { dark_mode: true } } }

    before do
      allow(Redis).to receive(:new).and_return(redis_client)
      allow(redis_client).to receive(:get).and_return(config_data.to_json)
    end

    it 'loads configuration from Redis' do
      config = described_class.from_redis(
        host: 'localhost',
        key: 'feature_flags'
      )
      expect(config).to eq(config_data)
    end

    context 'when key does not exist' do
      before do
        allow(redis_client).to receive(:get).and_return(nil)
      end

      it 'raises LoadDataError' do
        expect do
          described_class.from_redis(
            host: 'localhost',
            key: 'nonexistent'
          )
        end.to raise_error(HatiConfig::LoadDataError)
      end
    end

    context 'when Redis connection fails' do
      before do
        allow(redis_client).to receive(:get)
          .and_raise(Redis::CannotConnectError)
      end

      it 'raises LoadDataError' do
        expect do
          described_class.from_redis(
            host: 'localhost',
            key: 'feature_flags'
          )
        end.to raise_error(HatiConfig::LoadDataError)
      end
    end
  end
end

