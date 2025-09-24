# frozen_string_literal: true

require "spec_helper"

RSpec.describe HatiConfig::Cache do
  let(:dummy_class) do
    Class.new do
      extend HatiConfig::Cache
    end
  end

  describe "#cache" do
    it "creates a cache configuration with default values" do
      config = dummy_class.cache

      expect(config.adapter_type).to eq(:memory)
      expect(config.ttl).to eq(300)
      expect(config.stale_while_revalidate).to be false
    end

    it "configures cache with a block" do
      config = dummy_class.cache do
        adapter :redis, url: "redis://localhost:6379/0"
        ttl 600
        stale_while_revalidate true
      end

      expect(config.adapter_type).to eq(:redis)
      expect(config.adapter_options).to eq(url: "redis://localhost:6379/0")
      expect(config.ttl).to eq(600)
      expect(config.stale_while_revalidate).to be true
    end
  end

  describe "CacheConfig" do
    let(:config) { dummy_class.cache }

    describe "#refresh" do
      it "configures refresh behavior" do
        config.refresh do
          interval 30
          jitter 5
          backoff do
            initial 2
            multiplier 3
            max 600
          end
        end

        expect(config.refresh.interval).to eq(30)
        expect(config.refresh.jitter).to eq(5)
        expect(config.refresh.backoff_config.initial).to eq(2)
        expect(config.refresh.backoff_config.multiplier).to eq(3)
        expect(config.refresh.backoff_config.max).to eq(600)
      end
    end

    describe "MemoryAdapter" do
      let(:adapter) { config.adapter }

      it "stores and retrieves values" do
        adapter.set("key", "value", 60)
        expect(adapter.get("key")).to eq("value")
      end

      it "respects TTL" do
        adapter.set("key", "value", 0)
        expect(adapter.get("key")).to be_nil
      end

      it "deletes values" do
        adapter.set("key", "value", 60)
        adapter.delete("key")
        expect(adapter.get("key")).to be_nil
      end
    end

    describe "RedisAdapter" do
      let(:redis_client) { instance_double(Redis) }
      let(:connection_pool) { instance_double(ConnectionPool) }
      let(:redis_config) do
        dummy_class.cache do
          adapter :redis, url: "redis://localhost:6379/0"
        end
      end

      let(:adapter) { redis_config.adapter }

      before do
        allow(ConnectionPool).to receive(:new).and_return(connection_pool)
        allow(connection_pool).to receive(:with).and_yield(redis_client)
        allow(redis_client).to receive(:setex)
        allow(redis_client).to receive(:get)
        allow(redis_client).to receive(:del)
      end

      it "stores and retrieves values" do
        value = "value"
        serialized_value = Marshal.dump(value)
        allow(redis_client).to receive(:get).and_return(serialized_value)
        adapter.set("key", value, 60)
        expect(adapter.get("key")).to eq(value)
        expect(redis_client).to have_received(:setex).with("key", 60, serialized_value)
      end

      it "respects TTL" do
        value = "value"
        serialized_value = Marshal.dump(value)
        allow(redis_client).to receive(:get).and_return(serialized_value, nil)
        adapter.set("key", value, 1)
        expect(adapter.get("key")).to eq(value)
        # Simulate time passing, Redis handles actual expiry
        expect(adapter.get("key")).to be_nil
      end

      it "deletes values" do
        value = "value"
        adapter.set("key", value, 60)
        adapter.delete("key")
        expect(redis_client).to have_received(:del).with("key")
      end

      it "handles complex objects" do
        value = { array: [1, 2, 3], hash: { key: "value" } }
        serialized_value = Marshal.dump(value)
        allow(redis_client).to receive(:get).and_return(serialized_value)
        adapter.set("key", value, 60)
        expect(adapter.get("key")).to eq(value)
      end
    end
  end

  describe "RefreshConfig" do
    let(:config) { dummy_class.cache.refresh }

    describe "#next_refresh_time" do
      it "includes interval" do
        config.interval(30)
        config.jitter(0)

        next_time = config.next_refresh_time
        expect(next_time).to be_within(1).of(Time.now + 30)
      end

      it "includes random jitter" do
        config.interval(30)
        config.jitter(10)

        times = 10.times.map { config.next_refresh_time }
        jitters = times.map { |t| t - (Time.now + 30) }

        expect(jitters.min).to be >= 0
        expect(jitters.max).to be <= 10
        expect(jitters.uniq.size).to be > 1
      end
    end
  end

  describe "BackoffConfig" do
    let(:config) { dummy_class.cache.refresh.backoff_config }

    describe "#backoff_time" do
      before do
        config.initial(1)
        config.multiplier(2)
        config.max(8)
      end

      it "starts with initial time" do
        expect(config.backoff_time(1)).to eq(1)
      end

      it "applies multiplier for subsequent attempts" do
        expect(config.backoff_time(2)).to eq(2)
        expect(config.backoff_time(3)).to eq(4)
        expect(config.backoff_time(4)).to eq(8)
      end

      it "respects maximum time" do
        expect(config.backoff_time(5)).to eq(8)
      end
    end
  end
end
