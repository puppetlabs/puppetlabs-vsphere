require 'rake/task_arguments'
require 'rake/tasklib'
require 'rake'

# We clear the Beaker rake tasks from spec_helper as they assume
# rspec-puppet and a certain filesystem layout
Rake::Task[:beaker_nodes].clear
Rake::Task[:beaker].clear

module Beaker
  module Tasks
    class RakeTask < ::Rake::TaskLib
      include ::Rake::DSL if defined?(::Rake::DSL)

      [
        :name,
        :keyfile,
        :config,
        :debug,
        :tests,
        :pe_dir,
      ].each do |sym|
        attr_accessor(sym.to_sym)
      end

      def initialize(name, *args, &task_block)
        @name = name
        define(args, &task_block)
      end

      private
      def run_task(verbose)
        ENV['BEAKER_PE_DIR'] = pe_dir
        system(beaker_command)
      end

      def define(args, &task_block)
        task name, *args do |_, task_args|
          RakeFileUtils.__send__(:verbose, verbose) do
            task_block.call(*[self, task_args].slice(0, task_block.arity)) if task_block
            run_task verbose
          end
        end
      end

      def beaker_command
        cmd_parts = []
        cmd_parts << "beaker"
        cmd_parts << "--debug" if @debug
        cmd_parts << "--config #{@config}"
        cmd_parts << "--keyfile #{@keyfile}" if @keyfile
        cmd_parts << "--test #{@tests}"
        cmd_parts << "--pre-suite integration/pre-suite"
        cmd_parts << "--load-path integration/lib"
        cmd_parts << "--timeout 360"
        cmd_parts.flatten.join(" ")
      end
    end
  end
end

PE_RELEASES = {
  '3.8.3' => 'http://pe-releases.puppetlabs.lan/3.8.3/',
  '2015.2' => 'http://pe-releases.puppetlabs.lan/2015.2.3/',
  '2015.3' => 'http://pe-releases.puppetlabs.lan/2015.3.0/',
}

namespace :integration do
  {
    :vagrant => [
      'ubuntu1404',
      'centos7',
    ],
    :pooler => [
      'centos6',
      'centos7',
      'rhel7',
      'ubuntum_debian7a',
      'rhel7m_scientific7a',
    ]
  }.each do |ns, configs|
    namespace ns.to_sym do
      configs.each do |config|
        PE_RELEASES.each do |version, pe_dir|
          desc "Run integration tests for #{config} on #{ns} with PE #{version}"
          Beaker::Tasks::RakeTask.new("#{config}_#{version}".to_sym => [:spec_prep]) do |task, args|
            task.config = "integration/hosts/#{ns}/#{config}.cfg"
            task.pe_dir = ENV['BEAKER_PE_DIR'] || pe_dir
            task.keyfile = '~/.ssh/id_rsa-acceptance' if ns == :pooler
            task.debug = true if ENV['BEAKER_DEBUG']
            task.tests = ENV['TESTS'] || 'integration/tests'
          end
        end
      end
    end
  end
end
