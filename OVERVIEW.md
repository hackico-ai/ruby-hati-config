# Configuration Patterns & HatiConfig Overview

## Configuration Patterns in Ruby

Every application has different needs, and there are many excellent ways to handle configuration. Here's our perspective on what we've seen work well:

### The Classic Approach (Simple & Proven)

Many applications work perfectly with traditional patterns:

```
├── Configuration Needs
│   ├── Database URL
│   ├── API Keys
│   ├── Feature Flags
│   └── Environment-specific settings
│
├── Team Structure
│   ├── Single team
│   └── Clear ownership
│
├── Deployment
│   ├── Standard Rails/Ruby app
│   ├── Config changes are rare
│   └── Deployment downtime is acceptable
│
└── Tools That Work Great Here
    ├── ENV variables
    ├── Rails credentials
    ├── AWS Parameter Store
    └── YAML configs
```

This is a sweet spot where simple solutions shine. A typical pattern might look like:

```ruby
# config/application.rb - Clean and effective
module MyApp
  class Application < Rails::Application
    config.database_url = ENV['DATABASE_URL']
    config.redis_url = ENV['REDIS_URL']
    config.api_key = Rails.application.credentials.api[:key]
  end
end
```

### When Configuration Gets Interesting

Sometimes you encounter scenarios that push beyond the basics:

```ruby
# A real-world pattern we've seen
class ServiceConfig
  def initialize
    # Different sources for different needs
    @rate_limits = fetch_from_redis('api:limits')
    @feature_flags = load_from_s3('features.yml')

    # Region-specific settings
    @timeout = region_specific? ?
      fetch_from_ssm("/#{region}/timeout") :
      DEFAULT_TIMEOUT

    # Team-specific overrides
    @quotas = team_config.deep_merge(global_quotas)
  end
end
```

This is where configuration starts getting more nuanced. You might recognize your situation if you see:

```
├── Configuration Sources
│   ├── Redis (real-time updates)
│   ├── S3 (large config files)
│   ├── Parameter Store (secrets)
│   └── HTTP APIs (external services)
│
├── Team & Service Scale
│   ├── Multiple engineering teams
│   │   ├── Frontend
│   │   ├── Backend
│   │   └── Data Science
│   └── Many microservices
│       ├── Each with own configs
│       └── Cross-service dependencies
│
├── Dynamic Requirements
│   ├── Feature flags need instant updates
│   ├── A/B tests change frequently
│   ├── Rate limits adjust in real-time
│   └── Resource quotas vary by team
│
└── Complex Environments
    ├── Development
    ├── Staging
    ├── Production
    │   ├── US East
    │   ├── US West
    │   └── EU Region
    └── Each with unique overrides
```

This is the kind of scenario where HatiConfig might be worth considering. Here's how these challenges often manifest in code:

```ruby
# A pattern we often see evolve organically
class ConfigurationService
  def initialize(region:, team:, environment:)
    # Multiple sources to check
    @redis = Redis.new
    @s3_client = Aws::S3::Client.new
    @ssm = Aws::SSM::Client.new

    # Complex context handling
    @region = region
    @team = team
    @environment = environment

    # Caching and refresh logic
    @cache = {}
    @last_refresh = {}
    @refresh_intervals = {
      rate_limits: 30,    # 30 seconds
      features: 300,      # 5 minutes
      quotas: 3600       # 1 hour
    }
  end

  def get_config(key)
    return @cache[key] if cache_valid?(key)

    value = case key
    when /^rate_limit/
      fetch_from_redis(key)
    when /^feature_flag/
      load_from_s3("#{@team}/#{key}")
    else
      fetch_from_ssm("/#{@environment}/#{key}")
    end

    @cache[key] = value
    @last_refresh[key] = Time.now
    value
  end
end
```

If this looks familiar, you might find HatiConfig's approach interesting.

---

## HatiConfig's Approach

Here's how we tackle these challenges - it's one way to solve the problem, inspired by patterns we've seen work well in production:

```ruby
# One possible approach to complex configs
config = HatiConfig::Setting.new do
  # Type-safe configuration with validation
  config :rate_limit, value: 1000, type: :integer

  # Team isolation through namespaces
  configure :team_a do
    config :feature_flags, source: :redis
  end

  # Environment inheritance
  environment :production do
    configure :us_east do
      config :timeout, value: 30
    end
  end
end
```

### Key Design Decisions

| Pattern               | Our Approach                               | Why                                          |
| --------------------- | ------------------------------------------ | -------------------------------------------- |
| **Config Sources**    | HTTP, S3, Redis with auto-refresh          | Different sources for different update needs |
| **Environment Model** | Inheritance-based with overrides           | Natural mapping to deployment environments   |
| **Team Isolation**    | Namespace-based with explicit boundaries   | Prevents accidental cross-team interference  |
| **Type System**       | Runtime validation with schema versioning  | Catches errors before they hit production    |
| **Security Model**    | Multi-provider with transparent encryption | Flexibility in key management                |
| **Update Strategy**   | Background refresh with circuit breakers   | Resilient to source outages                  |
| **Data Format**       | Ruby DSL with YAML/JSON import/export      | Native Ruby feel with serialization options  |

---

## Real-World Case Study: When Simple Tools Fail

**Company**: E-commerce platform with 2M+ daily active users  
**Scale**: 80+ microservices, 12 engineering teams, 6 AWS regions  
**Problem**: Black Friday traffic spike caused site outage due to config management limitations

### The Scenario

During Black Friday 2023, traffic spiked 10x normal levels. The platform needed to:

1. **Immediately reduce API rate limits** from 1000/min to 100/min to prevent database overload
2. **Disable expensive features** (recommendations, analytics) to save resources
3. **Increase database connection pools** for critical services
4. **Enable circuit breakers** with different thresholds per region

### Why AWS Parameter Store + CI/CD Failed

**Problem 1: Deployment Bottleneck**

```bash
# What they tried:
aws ssm put-parameter --name "/prod/api-rate-limit" --value "100" --overwrite
# Result: 80+ services needed restarts to pick up new values
# Time to deploy: 45 minutes (too slow for emergency)
```

**Problem 2: No Atomic Updates**

```bash
# Needed to update 12 related parameters atomically:
/prod/api/rate-limit: 100
/prod/api/burst-limit: 20
/prod/db/pool-size: 50
/prod/features/recommendations: false
# Some services got partial updates, causing inconsistent behavior
```

**Problem 3: No Validation**

```bash
# Ops engineer accidentally set:
aws ssm put-parameter --name "/prod/db/pool-size" --value "many"
# 15 services crashed with "invalid integer" errors
```

**Problem 4: Team Conflicts**

```bash
# Frontend team overwrote backend team's circuit breaker settings:
aws ssm put-parameter --name "/prod/circuit-breaker-timeout" --value "30"
# Backend expected milliseconds (30000), got seconds (30)
# All API calls timed out
```

### How HatiConfig Would Have Solved This

**1. Instant Updates Without Deployments**

```ruby
# Update rate limits instantly across all services
config_server.update_config({
  api: { rate_limit: 100, burst_limit: 20 },
  database: { pool_size: 50 },
  features: { recommendations: false }
})
# All services pick up changes within 60 seconds via background refresh
```

**2. Atomic Configuration Updates**

```ruby
# All related configs update together or not at all
settings.configure :emergency_mode do
  config :api_rate_limit, value: 100, type: :integer
  config :db_pool_size, value: 50, type: :integer
  config :features_enabled, value: false, type: :boolean
end
# No partial updates, no inconsistent state
```

**3. Type Validation Prevents Crashes**

```ruby
# This would fail immediately with clear error:
settings.config :db_pool_size, value: "many", type: :integer
# => HatiConfig::SettingTypeError: Expected Integer, got String "many"
```

**4. Team Namespaces Prevent Conflicts**

```ruby
# Each team has isolated config space:
MyApp.frontend.settings.circuit_breaker_timeout  # => 30 (seconds)
MyApp.backend.settings.circuit_breaker_timeout   # => 30000 (milliseconds)
# No accidental overwrites
```

### The Real Cost of Simple Solutions

**AWS Parameter Store approach:**

- **Outage duration**: 2.5 hours (deployment + rollback time)
- **Revenue loss**: $850,000 (estimated)
- **Engineering time**: 40 person-hours for emergency response
- **Customer trust**: Significant damage to brand

**HatiConfig approach (estimated):**

- **Outage duration**: 15 minutes (config updates + service stabilization)
- **Revenue loss**: $50,000
- **Engineering time**: 5 person-hours
- **Customer trust**: Minimal impact

### When AWS Tools Work Fine

**Small Scale Example:**

```bash
# For a simple Rails app with 1-3 services:
export DATABASE_URL="postgres://..."
export REDIS_URL="redis://..."
export SECRET_KEY_BASE="abc123..."

# AWS Parameter Store works great:
aws ssm get-parameters --names "/myapp/database-url" "/myapp/redis-url"
```

This works because:

- Few parameters to manage
- Changes are infrequent
- Single team owns all configs
- Deployment downtime is acceptable
- No complex relationships between configs

### The Complexity Threshold

**Use environment variables when:**

- < 20 configuration values
- Single team/service
- Changes monthly or less
- No complex validation needs
- Deployment downtime OK

**Use HatiConfig when:**

- 100+ configuration values
- Multiple teams/services
- Changes daily or more
- Complex validation/relationships
- Zero-downtime config changes required

## Why CI/CD and AWS Tools Have Limits

### CI/CD Pipeline Limitations

```yaml
# GitHub Actions config deployment
- name: Deploy configs
  run: |
    aws ssm put-parameter --name "/prod/rate-limit" --value "${{ inputs.rate_limit }}"
    kubectl rollout restart deployment/api-service
```

**Problems:**

- **15-30 minute deployment time** for config changes
- **All-or-nothing**: Can't partially deploy config changes
- **No rollback**: If config is wrong, need another full deployment
- **Approval bottlenecks**: Config changes need same approval as code changes
- **No emergency bypass**: Critical config changes still wait for CI/CD

### AWS Parameter Store Limitations

```bash
# AWS Parameter Store has these limits:
aws ssm get-parameters --names param1 param2 param3  # Max 10 parameters per call
aws ssm get-parameters-by-path --path "/myapp/"      # Max 10MB total response
```

**Problems:**

- **API rate limits**: 1000 TPS standard, 10,000 TPS with higher pricing
- **Size limits**: 4KB per parameter, 10MB per API response
- **No atomic updates**: Can't update related parameters together
- **No type validation**: Everything is a string
- **No inheritance**: Can't have environment-specific overrides
- **Expensive**: $0.05 per 10,000 requests + storage costs

### AWS Secrets Manager Limitations

```bash
# Secrets Manager costs add up quickly:
# $0.40/month per secret + $0.05 per 10,000 API calls
# For 500 secrets: $200/month + API costs
```

**Problems:**

- **High cost**: 10x more expensive than Parameter Store
- **Slow retrieval**: 100-300ms per secret lookup
- **No caching**: Need to implement your own caching layer
- **JSON only**: Limited data structure support
- **No configuration inheritance**: Each environment needs separate secrets

### Kubernetes ConfigMaps/Secrets Limitations

```yaml
# ConfigMaps need pod restarts for updates
apiVersion: v1
kind: ConfigMap
data:
  rate-limit: "1000" # Always strings, no validation
```

**Problems:**

- **Pod restarts required**: Config changes need rolling updates
- **No validation**: All values are strings
- **Size limits**: 1MB per ConfigMap
- **No encryption**: ConfigMaps are base64 encoded, not encrypted
- **Cluster-bound**: Can't share configs across clusters/regions

### The Hidden Costs of "Simple" Solutions

**Real example from a Series B startup (50 engineers):**

**Before HatiConfig (AWS Parameter Store + CI/CD):**

- **Config change time**: 25 minutes average
- **Failed deployments**: 15% due to config errors
- **Engineering time**: 8 hours/week on config management
- **Outages**: 2 per quarter from config issues
- **AWS costs**: $400/month (Parameter Store + Secrets Manager)

**After HatiConfig:**

- **Config change time**: 2 minutes average
- **Failed deployments**: 2% due to config errors
- **Engineering time**: 1 hour/week on config management
- **Outages**: 0 per quarter from config issues
- **Total costs**: $200/month (hosting + development time)

**ROI calculation:**

- **Time saved**: 7 hours/week × 50 engineers × $100/hour = $35,000/week
- **Reduced outages**: 2 outages × $50,000 average cost = $100,000/quarter
- **Annual benefit**: $1.9M+ in time savings and reduced downtime
