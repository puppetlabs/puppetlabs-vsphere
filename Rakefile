require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'puppet-syntax/tasks/puppet-syntax'

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

# Use our own metadata task so we can ignore the non-SPDX PE licence
Rake::Task[:metadata].clear
desc "Check metadata is valid JSON"
task :metadata do
  sh "bundle exec metadata-json-lint metadata.json --no-strict-license"
end

desc "Run syntax, lint, and spec tests."
task :test => [
  :metadata,
  :syntax,
  :lint,
  :spec,
]

namespace :integration do
  { :vagrant => [
    'ubuntu',
    'ubuntu_pe4',
    'centos7',
  ],
    :pooler => [
    'centos6',
    'centos7',
    'rhel7m_ubuntua',
    'ubuntum_rhel7a',
    'ubuntum_debian7a',
    'rhel7m_scientific7a',
  ]}.each do |ns, configs|
    namespace ns.to_sym do
      configs.each do |config|
        desc "Run integration tests for #{config} on #{ns}"
        task config.to_sym do
          begin
            require 'master_manipulator'
            Dir.chdir "integration" do
              sh("test_run_scripts/#{ns}/vsphere/vsphere_#{config}.sh")
            end
          rescue LoadError
            puts "\033[33m[Warning]\033[0m The integration tests require the" \
              ' master_manipulator gem which is only available from the internal' \
              ' gem mirror. Specify GEM_SOURCE and rerun bundle install'
          end
        end
      end
    end
  end
end
