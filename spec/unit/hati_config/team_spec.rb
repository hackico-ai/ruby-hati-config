# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HatiConfig::Team do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Team
    end
  end

  describe '#team' do
    it 'creates a new team configuration module' do
      team_module = dummy_class.team(:frontend) do
        configure :settings do
          config api_endpoint: '/api/v1'
          config cache_ttl: 300
        end
      end

      expect(team_module).to respond_to(:configure)
      expect(team_module.settings.api_endpoint).to eq('/api/v1')
      expect(team_module.settings.cache_ttl).to eq(300)
    end

    it 'supports environment-specific configuration' do
      HatiConfig::Environment.with_environment(:development) do
        dummy_class.team(:backend) do
          configure :settings do
            environment :development do
              config debug: true
            end

            environment :production do
              config debug: false
            end
          end
        end
      end

      expect(dummy_class.backend.settings.debug).to be true
    end

    it 'creates isolated configurations for each team' do
      dummy_class.team(:frontend) do
        configure :settings do
          config api_endpoint: '/api/v1'
        end
      end

      dummy_class.team(:backend) do
        configure :settings do
          config database_pool: 5
        end
      end

      expect(dummy_class.frontend.settings.api_endpoint).to eq('/api/v1')
      expect(dummy_class.backend.settings.database_pool).to eq(5)
      expect { dummy_class.frontend.settings.database_pool }.to raise_error(NoMethodError)
      expect { dummy_class.backend.settings.api_endpoint }.to raise_error(NoMethodError)
    end
  end

  describe '#teams' do
    before do
      dummy_class.team(:frontend)
      dummy_class.team(:backend)
      dummy_class.team(:mobile)
    end

    it 'returns a list of defined teams' do
      expect(dummy_class.teams).to match_array(%i[Frontend Backend Mobile])
    end
  end

  describe '#[]' do
    before do
      dummy_class.team(:frontend) do
        configure :settings do
          config api_endpoint: '/api/v1'
        end
      end
    end

    it "returns the team's configuration module" do
      expect(dummy_class[:frontend].settings.api_endpoint).to eq('/api/v1')
    end

    it 'raises NameError for non-existent team' do
      expect { dummy_class[:unknown] }.to raise_error(NameError)
    end
  end

  describe '#team?' do
    before { dummy_class.team(:frontend) }

    it 'returns true for existing team' do
      expect(dummy_class.team?(:frontend)).to be true
    end

    it 'returns false for non-existent team' do
      expect(dummy_class.team?(:unknown)).to be false
    end
  end

  describe '#remove_team?' do
    before { dummy_class.team(:frontend) }

    it 'removes an existing team' do
      expect(dummy_class.remove_team?(:frontend)).to be true
      expect(dummy_class.team?(:frontend)).to be false
    end

    it 'returns false for non-existent team' do
      expect(dummy_class.remove_team?(:unknown)).to be false
    end
  end

  describe '#with_team' do
    before do
      dummy_class.team(:frontend) do
        configure :settings do
          config api_endpoint: '/api/v1'
        end
      end
    end

    it "executes block in team's context" do
      result = nil
      dummy_class.with_team(:frontend) do |team|
        result = team.settings.api_endpoint
      end
      expect(result).to eq('/api/v1')
    end

    it 'raises NameError for non-existent team' do
      expect { dummy_class.with_team(:unknown) { |_| nil } }.to raise_error(NameError)
    end
  end
end
