# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Schema do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Schema
    end
  end

  describe '#schema' do
    it 'creates a schema definition with version' do
      schema = dummy_class.schema(version: '2.0') do
        required :database_url, type: :string
        optional :pool_size, type: :integer, default: 5
      end

      expect(schema.version).to eq('2.0')
      expect(schema.required_fields).to include(:database_url)
      expect(schema.optional_fields).to include(:pool_size)
    end

    it 'defaults to version 1.0' do
      schema = dummy_class.schema do
        required :api_key, type: :string
      end

      expect(schema.version).to eq('1.0')
    end
  end

  describe '#schema_version' do
    it 'returns the current schema version' do
      dummy_class.schema(version: '2.0') { |s| s.field :name, type: String }
      expect(dummy_class.schema_version).to eq('2.0')
    end

    it 'defaults to 1.0' do
      expect(dummy_class.schema_version).to eq('1.0')
    end
  end

  describe 'SchemaDefinition' do
    let(:schema) do
      dummy_class.schema(version: '2.0') do
        required :database_url, type: :string, since: '1.0'
        required :replica_urls, type: [:string], since: '2.0'
        optional :pool_size, type: :integer, default: 5
        deprecated :old_setting, since: '2.0', remove_in: '3.0'
      end
    end

    describe '#validate' do
      let(:valid_data) do
        {
          database_url: 'postgres://localhost',
          replica_urls: ['postgres://replica1', 'postgres://replica2'],
          pool_size: 10
        }
      end

      it 'validates valid data' do
        expect { schema.validate(valid_data) }.not_to raise_error
      end

      it 'validates required fields' do
        invalid_data = valid_data.dup
        invalid_data.delete(:database_url)

        expect { schema.validate(invalid_data) }
          .to raise_error(HatiConfig::Schema::ValidationError, /Missing required field/)
      end

      it 'validates field types' do
        invalid_data = valid_data.dup
        invalid_data[:pool_size] = 'not an integer'

        expect { schema.validate(invalid_data) }
          .to raise_error(HatiConfig::Schema::ValidationError, /Invalid type/)
      end

      it 'validates array types' do
        invalid_data = valid_data.dup
        invalid_data[:replica_urls] = 'not an array'

        expect { schema.validate(invalid_data) }
          .to raise_error(HatiConfig::Schema::ValidationError, /Invalid type/)
      end

      it 'handles version-specific required fields' do
        data_without_replica = valid_data.dup
        data_without_replica.delete(:replica_urls)

        expect { schema.validate(data_without_replica, '1.0') }.not_to raise_error
        expect { schema.validate(data_without_replica, '2.0') }
          .to raise_error(HatiConfig::Schema::ValidationError, /Missing required field/)
      end

      it 'warns about deprecated fields' do
        data_with_deprecated = valid_data.dup
        data_with_deprecated[:old_setting] = 'value'

        expect do
          schema.validate(data_with_deprecated)
        end.to output(/deprecated since version 2.0/).to_stderr
      end

      it 'raises error for removed fields' do
        data_with_removed = valid_data.dup
        data_with_removed[:old_setting] = 'value'

        expect { schema.validate(data_with_removed, '3.0') }
          .to raise_error(HatiConfig::Schema::ValidationError, /was removed in version/)
      end
    end

    describe '#migrate' do
      before do
        schema.add_migration('1.0', '2.0') do |config|
          config[:replica_urls] = [config.delete(:backup_url)].compact
        end
      end

      it 'migrates configuration data' do
        old_data = {
          database_url: 'postgres://localhost',
          backup_url: 'postgres://backup',
          pool_size: 5
        }

        new_data = schema.migrate(old_data, '1.0', '2.0')

        expect(new_data[:replica_urls]).to eq(['postgres://backup'])
        expect(new_data).not_to include(:backup_url)
      end

      it 'raises error for missing migration path' do
        expect { schema.migrate({}, '1.0', '3.0') }
          .to raise_error(HatiConfig::Schema::MigrationError, /No migration path/)
      end
    end
  end
end
