# frozen_string_literal: true

require "spec_helper"

RSpec.describe HatiConfig::TypeMap do
  describe ".get" do
    it { expect(described_class.get(:int)).to eq(Integer) }
    it { expect(described_class.get(:str)).to eq(String) }
    it { expect(described_class.get(:hash)).to eq(Hash) }
    it { expect(described_class.get(:array)).to eq(Array) }
    it { expect(described_class.get(:big_decimal)).to eq(BigDecimal) }
    it { expect(described_class.get(:float)).to eq(Float) }
    it { expect(described_class.get(:date)).to eq(Date) }
    it { expect(described_class.get(:true_class)).to eq(TrueClass) }
    it { expect(described_class.get(:false_class)).to eq(FalseClass) }
    it { expect(described_class.get(:unknown)).to be_nil }
  end

  context "when defining TypeMap types" do
    let(:base_types) do
      %i[
        int integer str string sym null true_class false_class hash array big_decimal float
        complex rational date date_time time any
      ]
    end

    let(:composite_types) do
      {
        bool: %i[true_class false_class],
        numeric: %i[int float big_decimal],
        kernel_num: %i[int float big_decimal complex rational],
        chrono: %i[date date_time time]
      }
    end

    describe ".list_types" do
      it "returns an array of all type symbols defined in TYPE_MAP" do
        expect(described_class.list_types).to match_array(base_types + composite_types.keys)
      end
    end

    describe "TYPE_MAP constant" do
      it "contains the expected keys" do
        expect(HatiConfig::TypeMap::TYPE_MAP.keys).to match_array(base_types + composite_types.keys)
      end

      it "maps numeric composite type correctly" do
        expect(HatiConfig::TypeMap::TYPE_MAP[:numeric]).to eq(composite_types[:numeric])
      end

      it "maps kernel_num composite type correctly" do
        expect(HatiConfig::TypeMap::TYPE_MAP[:kernel_num]).to eq(composite_types[:kernel_num])
      end

      it "maps chrono composite type correctly" do
        expect(HatiConfig::TypeMap::TYPE_MAP[:chrono]).to eq(composite_types[:chrono])
      end
    end
  end
end
