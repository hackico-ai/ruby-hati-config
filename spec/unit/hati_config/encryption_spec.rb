# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Encryption do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Encryption
    end
  end

  describe '#encryption' do
    it 'creates an encryption configuration with default values' do
      config = dummy_class.encryption

      expect(config.algorithm).to eq('aes')
      expect(config.key_size).to eq(256)
      expect(config.mode).to eq('gcm')
      expect(config.key_provider).to be_nil
    end

    it 'configures encryption with a block' do
      config = dummy_class.encryption do
        algorithm 'aes'
        key_size 128
        mode 'cbc'
        key_provider :env, env_var: 'MY_ENCRYPTION_KEY'
      end

      expect(config.algorithm).to eq('aes')
      expect(config.key_size).to eq(128)
      expect(config.mode).to eq('cbc')
      expect(config.key_provider).to be_a(HatiConfig::Encryption::EnvKeyProvider)
    end
  end

  describe 'EncryptionConfig' do
    let(:config) { dummy_class.encryption }

    describe '#encrypt and #decrypt' do
      before do
        ENV['HATI_CONFIG_ENCRYPTION_KEY'] = '0' * 32 # 256-bit key
        config.key_provider :env
      end

      after do
        ENV.delete('HATI_CONFIG_ENCRYPTION_KEY')
      end

      it 'encrypts and decrypts values' do
        value = 'sensitive data'
        encrypted = config.encrypt(value)
        expect(encrypted).not_to eq(value)
        expect(config.decrypt(encrypted)).to eq(value)
      end

      it 'encrypts and decrypts non-string values' do
        value = { key: 'value', number: 123 }
        encrypted = config.encrypt(value)
        expect(encrypted).not_to eq(value.to_s)
        expect(config.decrypt(encrypted)).to eq(value.to_s)
      end

      it 'raises error when decrypting invalid data' do
        expect { config.decrypt('invalid base64!') }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /Invalid encrypted value/)
      end

      it 'raises error when no key provider is configured' do
        config = HatiConfig::Encryption::EncryptionConfig.new
        expect { config.encrypt('value') }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /No key provider configured/)
      end
    end

    describe 'KeyProvider' do
      describe '.create' do
        it 'creates an EnvKeyProvider' do
          provider = HatiConfig::Encryption::KeyProvider.create(:env, env_var: 'MY_KEY')
          expect(provider).to be_a(HatiConfig::Encryption::EnvKeyProvider)
        end

        it 'creates a FileKeyProvider' do
          provider = HatiConfig::Encryption::KeyProvider.create(:file, file_path: '/path/to/key')
          expect(provider).to be_a(HatiConfig::Encryption::FileKeyProvider)
        end

        it 'creates an AwsKmsKeyProvider' do
          provider = HatiConfig::Encryption::KeyProvider.create(:aws_kms, key_id: 'key-id', region: 'us-west-2')
          expect(provider).to be_a(HatiConfig::Encryption::AwsKmsKeyProvider)
        end

        it 'raises error for unknown provider type' do
          expect { HatiConfig::Encryption::KeyProvider.create(:unknown) }
            .to raise_error(HatiConfig::Encryption::EncryptionError, /Unknown key provider/)
        end
      end
    end

    describe 'EnvKeyProvider' do
      let(:provider) { HatiConfig::Encryption::KeyProvider.create(:env, env_var: 'MY_KEY') }

      it 'gets key from environment variable' do
        ENV['MY_KEY'] = 'test-key'
        expect(provider.key).to eq('test-key')
        ENV.delete('MY_KEY')
      end

      it 'raises error when environment variable is not set' do
        ENV.delete('MY_KEY')
        expect { provider.key }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /not found in environment variable/)
      end
    end

    describe 'FileKeyProvider' do
      let(:provider) { HatiConfig::Encryption::KeyProvider.create(:file, file_path: 'test.key') }

      it 'gets key from file' do
        allow(File).to receive(:exist?).with('test.key').and_return(true)
        allow(File).to receive(:read).with('test.key').and_return("test-key\n")
        expect(provider.key).to eq('test-key')
      end

      it 'raises error when file does not exist' do
        allow(File).to receive(:exist?).with('test.key').and_return(false)
        expect { provider.key }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /Key file not found/)
      end

      it 'raises error when file cannot be read' do
        allow(File).to receive(:exist?).with('test.key').and_return(true)
        allow(File).to receive(:read).with('test.key').and_raise(SystemCallError.new('Permission denied'))
        expect { provider.key }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /Failed to read key file/)
      end
    end

    describe 'AwsKmsKeyProvider' do
      let(:provider) { HatiConfig::Encryption::KeyProvider.create(:aws_kms, key_id: 'key-id', region: 'us-west-2') }
      let(:kms_client) { instance_double(Aws::KMS::Client) }
      let(:kms_response) { instance_double(Aws::KMS::Types::GenerateDataKeyResponse, plaintext: 'kms-key') }

      before do
        allow(Aws::KMS::Client).to receive(:new).and_return(kms_client)
        allow(kms_client).to receive(:generate_data_key).and_return(kms_response)
      end

      it 'gets key from AWS KMS' do
        expect(provider.key).to eq('kms-key')
        expect(kms_client).to have_received(:generate_data_key)
          .with(key_id: 'key-id', key_spec: 'AES_256')
      end

      it 'raises error when KMS request fails' do
        allow(kms_client).to receive(:generate_data_key)
          .and_raise(Aws::KMS::Errors::ServiceError.new(nil, 'KMS error'))
        expect { provider.key }
          .to raise_error(HatiConfig::Encryption::EncryptionError, /Failed to get key from KMS/)
      end

      it 'caches the key' do
        2.times { provider.key }
        expect(kms_client).to have_received(:generate_data_key).once
      end
    end
  end
end
