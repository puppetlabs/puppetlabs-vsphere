source "https://rubygems.org"

gem 'rbvmomi'

group :test do
  gem 'rake'
  gem 'puppet', ENV['PUPPET_VERSION'] || '~> 3.7.0'
  gem 'rspec-puppet', :git => 'https://github.com/rodjek/rspec-puppet.git'
  gem 'puppetlabs_spec_helper'
  gem 'mustache'
end

group :development do
  gem 'pry'
  gem 'puppet-blacksmith'
  gem 'guard-rake'
  gem 'metadata-json-lint'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
end
