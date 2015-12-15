source ENV['GEM_SOURCE'] || "https://rubygems.org"

gem 'rbvmomi'
gem 'hocon'

group :test do
  gem 'rake'
  gem 'puppet', ENV['PUPPET_GEM_VERSION'] || '~> 3.8.0'
  gem 'rspec-puppet', :git => 'https://github.com/rodjek/rspec-puppet.git'
  gem 'puppetlabs_spec_helper'
  gem 'metadata-json-lint'
end

group :development do
  gem 'pry'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
end

group :acceptance do
  gem 'mustache', '0.99.8'
end

group :integration do
  gem 'beaker'
  gem 'master_manipulator', '1.1.2'
end
