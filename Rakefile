require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'
require 'metadata-json-lint/rake_task'

# This gem isn't always present, for instance
# on Travis with --without development
begin
  require 'puppet_blacksmith/rake_tasks'
rescue LoadError
end

exclude_paths = [
  "pkg/**/*",
  "vendor/**/*",
  "spec/**/*",
]

Rake::Task[:lint].clear

PuppetLint.configuration.relative = true
PuppetLint.configuration.disable_80chars
PuppetLint.configuration.disable_class_inherits_from_params_class
PuppetLint.configuration.fail_on_warnings = true
PuppetLint::RakeTask.new :lint do |config|
  config.ignore_paths = exclude_paths
end

PuppetSyntax.exclude_paths = exclude_paths

desc "Run acceptance tests"
RSpec::Core::RakeTask.new(:acceptance) do |t|
  t.pattern = 'spec/acceptance'
end

desc "Run syntax, lint, and spec tests."
task :test => [
  :syntax,
  :lint,
  :spec,
]

namespace :integration do
  [
    'centos6',
    'centos7',
    'rhel7m_ubuntua',
    'ubuntum_rhel7a',
  ].each do |config|
    desc "Run integration tests for #{config}"
    task config.to_sym do
      begin
        require 'master_manipulator'
        sh("integration/test_run_scripts/vsphere/vsphere_#{config}.sh")
      rescue LoadError
        puts "\033[33m[Warning]\033[0m The integration tests require the" \
          ' master_manipulatotor gem which is only available from the internal' \
          ' gem mirror. Specify GEM_SOURCE and rerun bundle install'
      end
    end
  end
end
