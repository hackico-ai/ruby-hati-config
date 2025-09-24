# HatiConfig

A Ruby approach to configuration management, inspired by real-world challenges in distributed systems. This gem explores practical solutions for teams dealing with configuration complexity at scale.

## Table of Contents

- [Overview & Configuration Patterns](OVERVIEW.md)
- [Installation](#installation)
- [Basic Usage](#basic-usage)
- [Configuration Container Usage](#configuration-container-usage)
- [Define with DSL Syntax](#define-with-dsl-syntax)
- Distributed Features
  - [Remote Configuration](#remote-configuration)
  - [Environment Management](#environment-management)
  - [Team Isolation](#team-isolation)
  - [Schema Versioning](#schema-versioning)
  - [Caching and Refresh](#caching-and-refresh)
  - [Encryption](#encryption)
- Typing
  - [Configure Type Validation](#configure-type-validation)
  - [Define Configuration Type Validation](#define-configuration-type-validation)
  - [Type Schema](#type_schema)
  - [Built-in Types](#built-in-types)
- Import/Export:
  - [Loading Configurations](#loading-configuration-data)
  - [Loading from Remote Sources](#loading-from-remote-sources)
  - [Loading from a JSON String](#loading-from-a-json-string)
  - [Loading from a YAML File](#loading-from-a-yaml-file)
  - [Exporting Configurations](#exporting-configuration-data)
  - [to_h](#to_h)
  - [to_json](#to_json)
  - [to_yaml](#to_yaml)
- Security
  - [Encryption](#encryption)
  - [Encryption Key Providers](#encryption-key-providers)
  - [Security Features](#security-features)
- OSS
  - [Development](#development)
  - [Contributing](#contributing)
  - [License](#license)
  - [Code of Conduct](#code-of-conduct)

---

## Features

- **Simple Configuration Management**: Easily define, set, and retrieve configuration options.
- **Type Validation**: Ensure configurations are correct with built-in type validation.
- **Multiple Formats**: Import and export configurations in JSON, YAML, and Hash formats.
- **Nested Configurations**: Support for infinite nested configurations for complex applications.
- **Classy Access**: Access configurations in a 'classy' manner for better organization and readability.
- **Built-in Types**: Utilize various built-in types including basic types, data structures, numeric types, and time types.
- **Extensible**: Easily extendable to accommodate custom configuration needs.

## Recent Updates

### Version 1.1.0 (Latest)

- **Fixed**: Encryption functionality now works correctly with the `config(key, value: "secret", encrypted: true)` syntax
- **Enhanced**: Improved encryption handling for both inline and hash-based configuration syntax
- **Improved**: Better error handling and type validation for encrypted values
- **Updated**: Comprehensive encryption documentation with practical examples

---

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add hati-config
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install hati-config
```

## Basic Usage

**Use Case**: You're building a Ruby application that needs clean, type-safe configuration management. You want to avoid scattered constants, magic strings, and configuration bugs that crash production. You need nested configs, type validation, and the ability to export configs for debugging.

**Why existing tools fall short**:

- Plain Ruby constants are global and can't be nested cleanly
- YAML files lack type safety and runtime validation
- Environment variables become unwieldy with complex nested configs
- No built-in export/import capabilities for debugging and testing

**HatiConfig solution**: Clean DSL for defining configs with automatic type validation, nested namespaces, and built-in serialization.

```ruby
require 'hati_config'

module MyApp
  extend HatiConfig
end

MyApp.configure :settings do
  config option: 42
  config.int typed_opt_one: 42
  config typed_opt_two: 4.2, type: :float
end

MyApp.settings.option                 # => 42
MyApp.settings.typed_opt_one          # => 42
MyApp.settings.typed_opt_two          # => 4.2
```

### With Encryption

```ruby
require 'hati_config'

# Set up encryption key
ENV['HATI_CONFIG_ENCRYPTION_KEY'] = '0' * 32  # 256-bit key

# Create a setting instance with encryption
settings = HatiConfig::Setting.new

# Configure encryption
settings.class.encryption do
  key_provider :env
end

# Configure encrypted and plain values
settings.config :api_key, value: "secret-key", encrypted: true
settings.config :public_url, value: "https://api.example.com"

settings[:api_key]     # => "secret-key" (automatically decrypted)
settings[:public_url]  # => "https://api.example.com" (plain text)
```

### Basic Syntax

```ruby
MyApp.configure :settings do
  config option: 42
end
```

## Namespacing

```ruby
MyApp.configure :app do
  configure :lvl_one do
    config opt: 100
    configure :lvl_two do
      config opt: 200
      configure :lvl_three do
        config opt: 300
        configure :lvl_four do
          config opt: 400
          configure :lvl_five do
            config opt: 500
            # NOTE: as deep as you want
          end
        end
      end
    end
  end
end

MyApp.app.lvl_one.opt                                     # => 100
MyApp.app.lvl_one.lvl_two.opt                             # => 200
MyApp.app.lvl_one.lvl_two.lvl_three.opt                   # => 300
MyApp.app.lvl_one.lvl_two.lvl_three.lvl_four.opt          # => 400
MyApp.app.lvl_one.lvl_two.lvl_three.lvl_four.lvl_five.opt # => 500
```

### Configure Type Validation

```ruby
MyApp.configure :settings do
  config custom_typed_opt_one: '42', type: :float
end
# => HatiConfig::SettingTypeError
```

## Distributed Features

### Remote Configuration

**Use Case**: You're running a microservices architecture with 50+ services across multiple regions. Each service needs to know database endpoints, API keys, and feature flags that change frequently. Traditional config files mean redeploying every service when anything changes, causing downtime and deployment bottlenecks.

**Why existing tools fall short**:

- Environment variables become unmanageable with hundreds of configs
- Config files require application restarts and deployments
- Tools like Consul require additional infrastructure and learning curve
- Most solutions don't handle automatic refresh or fallback gracefully

**HatiConfig solution**: Load configurations from HTTP endpoints, S3, or Redis with automatic refresh, caching, and fallback. Update configs without touching code or deployments.

HatiConfig supports loading configurations from various remote sources:

```ruby
require 'hati_config'

module MyApp
  extend HatiConfig

  # Load from HTTP endpoint
  configure :api_settings, http: {
    url: 'https://config-server/api-config.json',
    headers: { 'Authorization' => 'Bearer token' },
    refresh_interval: 300  # refresh every 5 minutes
  }

  # Load from S3
  configure :database_settings, s3: {
    bucket: 'my-configs',
    key: 'database.yml',
    region: 'us-west-2',
    refresh_interval: 600
  }

  # Load from Redis
  configure :feature_flags, redis: {
    host: 'redis.example.com',
    key: 'feature_flags',
    refresh_interval: 60
  }
end
```

### Environment Management

**Use Case**: Your application runs across development, staging, production, and multiple regional production environments. Each environment needs different database URLs, API endpoints, timeout values, and feature flags. Developers accidentally use production configs in development, or staging configs leak into production, causing outages.

**Why existing tools fall short**:

- Rails environments are limited and don't handle complex multi-region setups
- Multiple config files lead to duplication and inconsistency
- No validation that the right configs are loaded in the right environment
- Switching between environments requires manual file changes or complex deployment scripts

**HatiConfig solution**: Define base configurations with environment-specific overrides. Built-in environment detection with validation ensures the right configs are always loaded.

Easily manage configurations across different environments:

```ruby
module MyApp
  extend HatiConfig

  configure :settings do
    # Base configuration
    config :timeout, default: 30
    config :retries, default: 3

    # Environment-specific overrides
    environment :development do
      config :api_url, value: 'http://localhost:3000'
      config :debug, value: true
    end

    environment :staging do
      config :api_url, value: 'https://staging-api.example.com'
      config :timeout, value: 60
    end

    environment :production do
      config :api_url, value: 'https://api.example.com'
      config :timeout, value: 15
      config :retries, value: 5
    end
  end
end
```

### Team Isolation

**Use Case**: You work at a large tech company with 10+ engineering teams (Frontend, Backend, Mobile, DevOps, ML, etc.). Each team has their own configurations, but they all deploy to shared infrastructure. Teams accidentally override each other's configs, causing mysterious production issues that take hours to debug.

**Why existing tools fall short**:

- Shared config files create merge conflicts and accidental overwrites
- Namespace collisions are common (multiple teams using "database_url")
- No clear ownership or boundaries for configuration sections
- Changes by one team can break another team's services

**HatiConfig solution**: Create isolated namespaces for each team. Teams can safely manage their own configs without affecting others, while still sharing common infrastructure settings.

Prevent configuration conflicts between teams:

```ruby
module MyApp
  extend HatiConfig

  # Team-specific configuration namespace
  team :frontend do
    configure :settings do
      config :api_endpoint, value: '/api/v1'
      config :cache_ttl, value: 300
    end
  end

  team :backend do
    configure :settings do
      config :database_pool, value: 5
      config :worker_threads, value: 10
    end
  end

  team :mobile do
    configure :settings do
      config :push_notifications, value: true
      config :offline_mode, value: true
    end
  end
end

# Access team configurations
MyApp.frontend.settings.api_endpoint  # => '/api/v1'
MyApp.backend.settings.database_pool  # => 5
MyApp.mobile.settings.offline_mode    # => true
```

### Schema Versioning

**Use Case**: Your application has evolved over 2 years. The original config had simple database settings, but now includes complex microservice endpoints, ML model parameters, and feature flags. Old configs are incompatible with new code, but you need to support gradual rollouts and rollbacks without breaking existing deployments.

**Why existing tools fall short**:

- No versioning means breaking changes crash old application versions
- Manual migration scripts are error-prone and forgotten
- No way to validate that configs match the expected schema
- Rolling back code requires manually reverting config changes

**HatiConfig solution**: Version your configuration schemas with automatic migrations. Validate configs against expected schemas and handle version mismatches gracefully.

Track and validate configuration schema changes:

```ruby
module MyApp
  extend HatiConfig

  configure :settings, version: '2.0' do
    # Schema definition with version constraints
    schema do
      required :database_url, type: :string, since: '1.0'
      required :pool_size, type: :integer, since: '1.0'
      optional :replica_urls, type: [:string], since: '2.0'
      deprecated :old_setting, since: '2.0', remove_in: '3.0'
    end

    # Migrations for automatic updates
    migration '1.0' => '2.0' do |config|
      config.replica_urls = [config.delete(:backup_url)].compact
    end
  end
end
```

### Caching and Refresh

**Use Case**: Your application makes 1000+ requests per second and needs to check feature flags and rate limits on each request. Fetching configs from remote sources every time would crush your config server and add 50ms latency to every request. But configs can change and you need updates within 1 minute for critical flags.

**Why existing tools fall short**:

- No caching means every request hits the config server
- Simple TTL caching means stale data during config server outages
- No intelligent refresh strategies lead to thundering herd problems
- Manual cache invalidation is complex and error-prone

**HatiConfig solution**: Intelligent caching with stale-while-revalidate, background refresh, exponential backoff, and jitter to prevent thundering herds.

Configure caching behavior and automatic refresh:

```ruby
module MyApp
  extend HatiConfig

  configure :settings do
    # Cache configuration
    cache do
      adapter :redis, url: 'redis://cache.example.com:6379/0'
      ttl 300  # 5 minutes
      stale_while_revalidate true
    end

    # Refresh strategy
    refresh do
      interval 60  # check every minute
      jitter 10    # add random delay (0-10 seconds)
      backoff do
        initial 1
        multiplier 2
        max 300
      end
    end
  end
end
```

### Encryption

**Use Case**: Your application handles API keys, database passwords, OAuth secrets, and encryption keys that are worth millions if compromised. These secrets are scattered across config files, environment variables, and deployment scripts. A single leaked config file or compromised CI/CD pipeline exposes everything. Compliance requires encryption at rest and audit trails.

**Why existing tools fall short**:

- Environment variables are visible in process lists and logs
- Config files with secrets get committed to Git accidentally
- Kubernetes secrets are base64 encoded, not encrypted
- External secret managers add complexity and network dependencies
- No transparent encryption/decryption in application code

**HatiConfig solution**: Automatic encryption of sensitive values with multiple key providers (env, files, AWS KMS). Values are encrypted at rest and decrypted transparently when accessed.

Secure sensitive configuration values with built-in encryption support:

```ruby
require 'hati_config'

# Set the encryption key via environment variable
ENV['HATI_CONFIG_ENCRYPTION_KEY'] = '0123456789abcdef' * 2  # 32-character key

# Create a settings instance
settings = HatiConfig::Setting.new

# Configure encryption with environment variable key provider
settings.class.encryption do
  key_provider :env  # Uses HATI_CONFIG_ENCRYPTION_KEY environment variable
  algorithm 'aes'    # AES encryption (default)
  key_size 256       # 256-bit keys (default)
  mode 'gcm'         # GCM mode (default)
end

# Configure settings with encrypted and plain values
settings.config :api_key, value: 'secret-api-key', encrypted: true
settings.config :database_password, value: 'super-secret-password', encrypted: true

# Regular unencrypted values
settings.config :api_url, value: 'https://api.example.com'

# Nested configurations with encryption
settings.configure :database do
  config :host, value: 'db.example.com'
  config :password, value: 'db-secret', encrypted: true
  config :username, value: 'app_user'
end

# Access values - encrypted values are automatically decrypted
settings[:api_key]              # => 'secret-api-key' (decrypted)
settings.database[:password]    # => 'db-secret' (decrypted)
settings[:api_url]              # => 'https://api.example.com' (plain)
```

#### Encryption Key Providers

The gem supports multiple key providers for encryption keys:

```ruby
# Environment variable (default)
settings.class.encryption do
  key_provider :env, env_var: 'MY_ENCRYPTION_KEY'  # Custom env var name
end

# File-based key
settings.class.encryption do
  key_provider :file, file_path: '/secure/path/to/key.txt'
end

# AWS KMS (requires aws-sdk-kms gem)
settings.class.encryption do
  key_provider :aws_kms, key_id: 'alias/config-key', region: 'us-west-2'
end
```

#### Security Features

- **AES-256-GCM encryption**: Industry-standard encryption with authentication
- **Automatic encryption/decryption**: Values are encrypted when stored and decrypted when accessed
- **Type safety**: Only string values can be encrypted (enforced at runtime)
- **Multiple key providers**: Support for environment variables, files, and AWS KMS
- **Secure storage**: Encrypted values are stored as Base64-encoded strings

## Configuration Container Usage

```ruby
require 'hati_config'

module MyGem
  extend HatiConfig
end
```

### Declare configurations

```ruby
MyGem.configure :settings do
  config :option
  config.int :typed_opt_one
  config :typed_opt_two, type: Integer
  # NOTE: declare nested namespace with configure <symbol arg>
  configure :nested do
    config :option
  end
end
```

### Define configurations

```ruby
MyGem.settings do
  config option: 1
  config typed_opt_one: 2
  config typed_opt_two: 3
  # NOTE: access namespace via <.dot_access>
  config.nested do
    config option: 4
  end
end
```

### Define with DSL Syntax

```ruby
MyGem.settings do
  option 'one'
  typed_opt_one 1
  typed_opt_two 2
  # NOTE: access namespace via <block>
  nested do
    option 'nested'
  end
end
```

### Get configurations

```ruby
MyGem.settings.option        # => 'one'
MyGem.settings.typed_opt_one # => 1
MyGem.settings.typed_opt_two # => 2
MyGem.settings.nested.option # => 'nested'
```

### Define Configuration Type Validation

```ruby
MyGem.settings do
  config.typed_opt_two: '1'
end
# => HatiConfig::SettingTypeError

MyGem.settings do
  typed_opt_two '1'
end
# => HatiConfig::SettingTypeError
```

### Union

```ruby
# List one of entries as built-in :symbols or classes

MyApp.configure :settings do
  config transaction_fee: 42, type: [Integer, :float, BigDecimal]
  config vendor_code: 42, type: [String, :int]
end
```

### Custom

```ruby
MyApp.configure :settings do
  config option: CustomClass.new, type: CustomClass
end
```

### Callable

```ruby
acc_proc = Proc.new { |val| val.respond_to?(:accounts) }
holder_lam = ->(name) { name.length > 5 }

MyApp.configure :settings do
  config acc_data: User.new, type: acc_proc
  config holder_name: 'John Doe', type: holder_lam
end
```

## Loading Configuration Data

**Use Case**: Your application needs to load configuration from existing YAML files, JSON APIs, or hash data from databases. You want to validate the loaded data against expected schemas and handle format errors gracefully. Different environments might use different config sources (files in development, APIs in production).

**Why existing tools fall short**:

- Manual YAML/JSON parsing is error-prone and lacks validation
- No schema validation means runtime errors from bad config data
- Mixing different config sources requires complex custom code
- No unified interface for different data formats

**HatiConfig solution**: Unified interface for loading from YAML, JSON, and Hash sources with optional schema validation and clear error handling.

The `HatiConfig` module allows you to load configuration data from various sources, including YAML and JSON. Below are the details for each option.

- `json` (String)
- `yaml` (String)
- `hash` (Hash)
- `schema` (Hash) (Optional) See: [Type Schema](#type_schema) and [Built-in Types](#built-in-types)

### Loading from a JSON String

You can load configuration data from a JSON string by passing the `json` option to the `configure` method.

#### Parameters

- `json` (String): A JSON string containing the configuration data.
- `schema` (Hash) (Optional): A hash representing the type schema for the configuration data.

#### Error Handling

- If the JSON format is invalid, a `LoadDataError` will be raised with the message "Invalid JSON format".

#### Example 1

```ruby
MyGem.configure(:settings, json: '{"opt_one":1,"opt_two":2}').settings
# => #<MyGem::Setting:0x00007f8c1c0b2a80 @options={:opt_one=>1, :opt_two=>2}>
```

#### Example 2

```ruby
MyGem.configure(:settings, json: '{"opt_one":1,"opt_two":2}', schema: { opt_one: :int, opt_two: :str })
# => HatiConfig::SettingTypeError: Expected: <str>. Given: 2 which is <Integer> class.
```

#### Example 3

```ruby
MyGem.configure(:settings, json: '{"opt_one":1,"opt_two":2}', schema: { opt_one: :int, opt_two: :int })

MyGem.settings do
  opt_one 1
  opt_two "2"
end
# => HatiConfig::SettingTypeError: Expected: <intstr>. Given: \"2\" which is <String> class.
```

### Loading from a YAML File

You can also load configuration data from a YAML file by passing the `yaml` option to the `configure` method.

#### Parameters

- `yaml` (String): A file path to a YAML file containing the configuration data.
- `schema` (Hash) (Optional): A hash representing the type schema for the configuration data.

#### Error Handling

- If the specified YAML file is not found, a `LoadDataError` will be raised with the message "YAML file not found".

##### YAML File

```yaml
# settings.yml

opt_one: 1
opt_two: 2
```

#### Example 1

```ruby
MyGem.configure :settings, yaml: 'settings.yml'
# => #<MyGem::Setting:0x00006f8c1c0b2a80 @options={:opt_one=>1, :opt_two=>2}>
```

#### Example 2

```ruby
MyGem.configure :settings, yaml: 'settings.yml', schema: { opt_one: :int, opt_two: :str }
# => HatiConfig::SettingTypeError: Expected: <str>. Given: 2 which is <Integer> class.
```

#### Example 3

```ruby
MyGem.configure :settings, yaml: 'settings.yml', schema: { opt_one: :int, opt_two: :int }

MyGem.settings do
  opt_one 1
  opt_two "2"
end
# => HatiConfig::SettingTypeError: Expected: <intstr>. Given: \"2\" which is <String> class.
```

## Exporting Configuration Data

You can dump the configuration data in various formats using the following methods:

### to_h

```ruby
MyGem.configure :settings do
  config opt_one: 1
  config opt_two: 2
end

MyGem.settings.to_json # => '{"opt_one":1,"opt_two":2}'
```

### to_json

```ruby
MyGem.configure :settings do
  config opt_one: 1
  config opt_two: 2
end

MyGem.settings.to_json # => '{"opt_one":1,"opt_two":2}'
```

### to_yaml

```ruby
MyGem.configure :settings do
  config opt_one: 1
  config opt_two: 2
end

MyGem.settings.to_yaml # => "---\nopt_one: 1\nopt_two: 2\n"
```

### type_schema

```ruby
MyGem.configure :settings do
  config.int opt_one: 1
  config.str opt_two: "2"
end

MyGem.settings.type_schema # => {:opt_one=>:int, :opt_two=>:str}
```

## Built-in Types Features

**Use Case**: Your application crashes in production because someone set a timeout to "30 seconds" instead of 30, or a database pool size to "many" instead of 10. You need runtime type validation that catches these errors early and provides clear error messages. Different config values need different types (strings, integers, arrays, custom objects).

**Why existing tools fall short**:

- No runtime type checking means silent failures or crashes
- Custom validation code is scattered throughout the application
- Error messages are unclear ("expected Integer, got String")
- No support for complex types like arrays of specific types or custom classes

**HatiConfig solution**: Comprehensive type system with built-in types, composite types, custom validators, and clear error messages.

### Base Types

```ruby
:int  => Integer
:str  => String
:sym  => Symbol
:null => NilClass
:any  => Object
:true_class  => TrueClass
:false_class => FalseClass
```

### Data Structures

```ruby
:hash  => Hash
:array => Array
```

### Numeric

```ruby
:big_decimal => BigDecimal,
:float       => Float,
:complex     => Complex,
:rational    => Rational,
```

### Time

```ruby
:date      => Date,
:date_time => DateTime,
:time      => Time,
```

### Composite

```ruby
:bool       => [TrueClass, FalseClass],
:numeric    => [Integer, Float, BigDecimal],
:kernel_num => [Integer, Float, BigDecimal, Complex, Rational],
:chrono     => [Date, DateTime, Time]
```

## Authors

- **Mariya Giy** ([@MarieGiy](https://github.com/MarieGiy))

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to publish the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and feature requests are welcome. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the HatiConfig project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the code of conduct.
