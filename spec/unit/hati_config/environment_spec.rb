# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Environment do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Environment

      def self.config_values
        @config_values ||= {}
      end

      def self.config(values)
        config_values.merge!(values)
      end
    end
  end

  describe '.current_environment=' do
    after { described_class.current_environment = nil }

    it 'sets the current environment' do
      described_class.current_environment = :production
      expect(described_class.current_environment).to eq(:production)
    end

    it 'converts string environment to symbol' do
      described_class.current_environment = 'staging'
      expect(described_class.current_environment).to eq(:staging)
    end
  end

  describe '.current_environment' do
    before do
      described_class.current_environment = nil
      ENV.delete('HATI_ENV')
      ENV.delete('RACK_ENV')
      ENV.delete('RAILS_ENV')
    end

    after do
      ENV.delete('HATI_ENV')
      ENV.delete('RACK_ENV')
      ENV.delete('RAILS_ENV')
    end

    it 'defaults to development' do
      expect(described_class.current_environment).to eq(:development)
    end

    it 'uses HATI_ENV environment variable' do
      ENV['HATI_ENV'] = 'production'
      expect(described_class.current_environment).to eq(:production)
    end

    it 'uses RACK_ENV environment variable' do
      ENV['RACK_ENV'] = 'staging'
      expect(described_class.current_environment).to eq(:staging)
    end

    it 'uses RAILS_ENV environment variable' do
      ENV['RAILS_ENV'] = 'test'
      expect(described_class.current_environment).to eq(:test)
    end

    it 'prioritizes HATI_ENV over other environment variables' do
      ENV['HATI_ENV'] = 'production'
      ENV['RACK_ENV'] = 'staging'
      ENV['RAILS_ENV'] = 'development'
      expect(described_class.current_environment).to eq(:production)
    end
  end

  describe '.with_environment' do
    it 'temporarily changes the environment' do
      original_env = described_class.current_environment
      result = described_class.with_environment(:test) do
        described_class.current_environment
      end
      expect(result).to eq(:test)
      expect(described_class.current_environment).to eq(original_env)
    end

    it 'restores the environment even if an error occurs' do
      original_env = described_class.current_environment
      begin
        described_class.with_environment(:test) { raise 'error' }
      rescue StandardError
        # Ignore error
      end
      expect(described_class.current_environment).to eq(original_env)
    end
  end

  describe '#environment' do
    before { described_class.current_environment = :development }
    after { described_class.current_environment = nil }

    it 'executes the block when environment matches' do
      dummy_class.environment(:development) do
        config(debug: true)
      end
      expect(dummy_class.config_values[:debug]).to be true
    end

    it 'does not execute the block when environment does not match' do
      dummy_class.environment(:production) do
        config(debug: true)
      end
      expect(dummy_class.config_values[:debug]).to be_nil
    end
  end

  describe 'environment checks' do
    after { described_class.current_environment = nil }

    context 'when in development' do
      before { described_class.current_environment = :development }

      it { expect(dummy_class.development?).to be true }
      it { expect(dummy_class.test?).to be false }
      it { expect(dummy_class.staging?).to be false }
      it { expect(dummy_class.production?).to be false }
    end

    context 'when in test' do
      before { described_class.current_environment = :test }

      it { expect(dummy_class.development?).to be false }
      it { expect(dummy_class.test?).to be true }
      it { expect(dummy_class.staging?).to be false }
      it { expect(dummy_class.production?).to be false }
    end

    context 'when in staging' do
      before { described_class.current_environment = :staging }

      it { expect(dummy_class.development?).to be false }
      it { expect(dummy_class.test?).to be false }
      it { expect(dummy_class.staging?).to be true }
      it { expect(dummy_class.production?).to be false }
    end

    context 'when in production' do
      before { described_class.current_environment = :production }

      it { expect(dummy_class.development?).to be false }
      it { expect(dummy_class.test?).to be false }
      it { expect(dummy_class.staging?).to be false }
      it { expect(dummy_class.production?).to be true }
    end
  end
end
