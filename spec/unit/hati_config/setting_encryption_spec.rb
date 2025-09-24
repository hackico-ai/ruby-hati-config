# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Setting do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Setting
    end
  end

  let(:settings) { described_class.new }

  before do
    ENV['HATI_CONFIG_ENCRYPTION_KEY'] = '0' * 32 # 256-bit key
    settings.class.encryption do
      key_provider :env
    end
  end

  after do
    ENV.delete('HATI_CONFIG_ENCRYPTION_KEY')
  end

  describe 'encrypted values' do
    it 'encrypts and decrypts values' do
      settings.config(:password, value: 'secret123', encrypted: true)
      encrypted_value = settings.instance_variable_get(:@config_tree)[:password]
      expect(encrypted_value).not_to eq('secret123')
      expect(settings[:password]).to eq('secret123')
    end

    it 'raises error for non-string encrypted values' do
      expect do
        settings.config(:number, value: 123, encrypted: true)
      end.to raise_error(HatiConfig::SettingTypeError, /must be strings/)
    end

    it 'handles encrypted values in nested settings' do
      settings.configure(:database) do
        config(:password, value: 'secret123', encrypted: true)
      end

      encrypted_value = settings.database.instance_variable_get(:@config_tree)[:password]
      expect(encrypted_value).not_to eq('secret123')
      expect(settings.database[:password]).to eq('secret123')
    end

    it 'preserves encryption when converting to hash' do
      settings.config(:password, value: 'secret123', encrypted: true)
      hash = settings.to_h
      expect(hash[:password]).to eq('secret123')
    end

    it 'preserves encryption in nested hashes' do
      settings.configure(:database) do
        config(:password, value: 'secret123', encrypted: true)
        config(:host, value: 'localhost')
      end

      hash = settings.to_h
      expect(hash[:database][:password]).to eq('secret123')
      expect(hash[:database][:host]).to eq('localhost')
    end

    it 'supports hash-like access for encrypted values' do
      settings[:password] = 'secret123'
      settings.config(:password, encrypted: true)
      expect(settings[:password]).to eq('secret123')
    end

    it 'supports multiple encrypted values' do
      settings.config(:password, value: 'secret123', encrypted: true)
      settings.config(:api_key, value: 'abc123', encrypted: true)
      settings.config(:host, value: 'localhost')

      expect(settings[:password]).to eq('secret123')
      expect(settings[:api_key]).to eq('abc123')
      expect(settings[:host]).to eq('localhost')
    end

    it 'preserves encryption when loading from hash' do
      settings.load_from_hash(
        {
          database: {
            password: 'secret123',
            host: 'localhost'
          }
        },
        schema: {
          database: {
            password: :string,
            host: :string
          }
        }
      )

      settings.configure(:database) do
        config(:password, encrypted: true)
      end

      expect(settings.database[:password]).to eq('secret123')
      expect(settings.database[:host]).to eq('localhost')
    end
  end
end
