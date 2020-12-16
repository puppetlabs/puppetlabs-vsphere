# frozen_string_literal: true

require 'mustache'
require 'rbvmomi'
require 'retries'
require 'puppet_litmus'
require 'singleton'

class Helper
  include Singleton
  include PuppetLitmus
end

class NotFinished < RuntimeError
end

VCENTER_ENV_VARS = ['VCENTER_USER', 'VCENTER_PASSWORD', 'VCENTER_SERVER', 'VCENTER_DATACENTER', 'VCENTER_GUEST_USERNAME', 'VCENTER_GUEST_PASSWORD'].freeze

def set_up_vcenter_env_vars
  missing_env_vars = VCENTER_ENV_VARS.select { |v| ENV[v].nil? }
  unless missing_env_vars.empty?
    raise 'Missing environment variables' \
          "\nThe following env vars were not set: #{missing_env_vars}.\n" \
          'Please refer to https://confluence.puppetlabs.com/display/ECO/vSphere+Module+Test+Overview for more details ' \
          'on how to configure these variables.'
  end

  VCENTER_ENV_VARS.each do |v|
    Helper.instance.run_shell("echo \"#{v}\"=\"#{ENV[v]}\" >> /etc/environment")
  end
end

def install_module_deps
  deb_pp = <<-MANIFEST
    $packages = [ 'zlib1g-dev', 'libxslt1-dev', 'build-essential' ]
    package { $packages: ensure => 'installed' }
  MANIFEST

  rhel_pp = <<-MANIFEST
    $packages = [ 'zlib-devel', 'libxslt-devel', 'patch', 'gcc', 'gcc-c++', 'kernel-devel', 'make' ]
    package { $packages: ensure => 'installed' }
  MANIFEST

  case os[:family]
  when 'ubuntu', 'debian'
    Helper.instance.apply_manifest(deb_pp)
  when 'redhat', 'centos', 'el'
    Helper.instance.apply_manifest(rhel_pp)
  end

  # FM-8880: The litmusimage/debian:10 container has mkdir installed at /bin/mkdir, instead of the /usr/bin/mkdir like all other OSs.
  # The nokogiri installation is hard-coded to look in /usr/bin/mkdir. If we're running in a Debian 10 container we'll need
  # to symlink /bin/mkdir -> /usr/bin/mkdir to allow the nokogiri gem installation to pass.
  if os[:family] == 'debian' && os[:release].to_f > 9
    Helper.instance.run_shell("if [[ `grep 'docker' /proc/1/cgroup` && -f /bin/mkdir && ! -f /usr/bin/mkdir ]]; then ln -s /bin/mkdir /usr/bin/mkdir; fi")
  end

  # FM-8880: When the nokogiri gem is installed as part of the installation of rbvmomi or hocon (as it's a dep of both),
  # the installation fails on RHEL 7.x derived OSs. We need to install nokogiri first, standalone before installing the
  # subsequent gems.
  Helper.instance.run_shell('/opt/puppetlabs/puppet/bin/gem install nokogiri --no-document')
  Helper.instance.run_shell('/opt/puppetlabs/puppet/bin/gem install rbvmomi --no-document')
  Helper.instance.run_shell("/opt/puppetlabs/puppet/bin/gem install hocon --version='~>1.0.0' --no-document")
end

RSpec.configure do |c|
  c.before :suite do
    set_up_vcenter_env_vars
    install_module_deps
  end
end

class VsphereHelper
  attr_reader :datacenter

  def initialize
    credentials = {
      host: ENV['VCENTER_SERVER'],
      user: ENV['VCENTER_USER'],
      password: ENV['VCENTER_PASSWORD'],
      insecure: true,
    }
    datacenter = ENV['VCENTER_DATACENTER']
    @vim = RbVmomi::VIM.connect credentials
    @datacenter = @vim.serviceInstance.find_datacenter(datacenter)
  end

  def get_machine(path)
    local_path = "/#{path.split('/').drop(3).join('/')}"
    @datacenter.find_vm(local_path)
  end

  def destroy_machine(path)
    machine = get_machine(path)
    if machine # rubocop:disable Style/GuardClause
      machine.PowerOffVM_Task.wait_for_completion if machine.runtime.powerState == 'poweredOn'
      machine.Destroy_Task.wait_for_completion
    end
  end

  def machine_credentials
    {
      interactiveSession: false,
      username: ENV['VCENTER_GUEST_USERNAME'],
      password: ENV['VCENTER_GUEST_PASSWORD'],
    }
  end

  def list_processes(path)
    machine = get_machine(path)
    manager = @vim.serviceContent.guestOperationsManager
    auth = RbVmomi::VIM::NamePasswordAuthentication(machine_credentials)
    with_retries(max_tries: 10,
                 max_sleep_seconds: 10,
                 rescue: NotFinished) do
      begin
        manager.authManager.ValidateCredentialsInGuest(vm: machine, auth: auth)
        manager.processManager.ListProcessesInGuest(vm: machine, auth: auth)
      rescue RbVmomi::Fault => exception
        raise NotFinished if exception.message.split(':').first == 'GuestOperationsUnavailable'
        # raise NotFinished
        # else
        raise unless exception.message.split(':').first == 'GuestOperationsUnavailable'
        # end
      end
    end
  end
end

class PuppetManifest < Mustache
  def initialize(file, config)
    @template_file = File.join(Dir.getwd, 'spec', 'acceptance', 'fixtures', file)
    config.each do |key, value|
      config_value = self.class.to_generalized_data(value)
      instance_variable_set("@#{key}".to_sym, config_value)
      self.class.send(:attr_accessor, key)
    end
  end

  def apply(opts = {})
    Helper.instance.apply_manifest(render.delete("\n"), opts)
  end

  def idempotent_apply
    Helper.instance.idempotent_apply(render.delete("\n"))
  end

  def self.to_generalized_data(val)
    case val
    when Hash
      to_generalized_hash_list(val)
    when Array
      to_generalized_array_list(val)
    else
      val
    end
  end

  # returns an array of :k =>, :v => hashes given a Hash
  # { :a => 'b', :c => 'd' } -> [{:k => 'a', :v => 'b'}, {:k => 'c', :v => 'd'}]
  def self.to_generalized_hash_list(hash)
    hash.map { |k, v| { k: k, v: v } }
  end

  # necessary to build like [{ :values => Array }] rather than [[]] when there
  # are nested hashes, for the sake of Mustache being able to render
  # otherwise, simply return the item
  def self.to_generalized_array_list(arr)
    arr.map do |item|
      if item.class == Hash
        {
          values: to_generalized_hash_list(item),
        }
      else
        item
      end
    end
  end
end

class TestExecutor
  # build and apply complex puppet resource commands
  # the arguement resource is the type of the resource
  # the opts hash must include a key 'name'
  def self.puppet_resource(resource, opts = {})
    raise 'A name for the resource must be specified' unless opts[:name]
    cmd = "puppet resource #{resource} "
    options = ''
    opts.each do |k, v|
      if k.to_s == 'name'
        @name = v
      else
        options << "#{k}=#{v} "
      end
    end
    cmd << "#{@name} "
    cmd << options
    # apply the command
    Helper.instance.run_shell(cmd)
  end
end
