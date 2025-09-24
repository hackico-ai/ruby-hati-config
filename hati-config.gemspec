# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'hati_config/version'

Gem::Specification.new do |spec|
  spec.name    = 'hati-config'
  spec.version = '0.1.0'
  spec.authors = ['Marie Giy']
  spec.email   = %w[giy.mariya@gmail.com]
  spec.license = 'MIT'

  spec.summary = 'Ruby configuration management for distributed systems and multi-team environments.'
  spec.description = 'A practical approach to configuration management with type safety, team isolation, environment inheritance, encryption, and remote sources. Designed for teams dealing with configuration complexity at scale.'
  spec.homepage = "https://github.com/hackico-ai/#{spec.name}"

  spec.required_ruby_version = '>= 3.0.0'

  spec.files         = Dir['CHANGELOG.md', 'LICENSE', 'README.md', 'hati-config.gemspec', 'lib/**/*']
  spec.bindir        = 'bin'
  spec.executables   = []
  spec.require_paths = ['lib']

  spec.metadata['repo_homepage']     = spec.homepage
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri']    = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_dependency 'aws-sdk-s3', '~> 1.0'
  spec.add_dependency 'bigdecimal', '~> 3.0'
  spec.add_dependency 'connection_pool', '~> 2.4'
  spec.add_dependency 'redis', '~> 5.0'
end
