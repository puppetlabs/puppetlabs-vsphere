require 'rbvmomi'
require 'mustache'
require 'open3'
require 'rbvmomi'
require 'retries'

RSpec::Matchers.define :require_string_for do |property|
  match do |type_class|
    config = { name: 'name' }
    config[property] = 2
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, %r{#{property} should be a String})
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be a String"
  end
end

RSpec::Matchers.define :require_hash_for do |property|
  match do |type_class|
    config = { name: 'name' }
    config[property] = 2
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, %r{#{property} should be a Hash})
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be a Hash"
  end
end

RSpec::Matchers.define :require_integer_for do |property|
  match do |type_class|
    config = { name: 'name' }
    config[property] = 'string'
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, %r{#{property} should be an Integer})
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be a Integer"
  end
end

RSpec::Matchers.define :be_read_only do |property|
  match do |type_class|
    config = { name: 'name' }
    config[property] = 'invalid'
    expect {
      type_class.new(config)
    }.to raise_error(Puppet::Error, %r{#{property} is read-only})
  end
  failure_message do |type_class|
    "#{type_class} should require #{property} to be read-only"
  end
end

class NotFinished < RuntimeError
end

class VsphereHelper
  attr_reader :datacenter

  def initialize
    credentials = {
      host: ENV['VCENTER_SERVER'] ||= '${{ secrets.VCENTER_SERVER }}',
      user: ENV['VCENTER_USER'] ||= '${{ secrets.VCENTER_USER }}',
      password: ENV['VCENTER_PASSWORD'] ||= '${{ secrets.VCENTER_PASSWORD }}',
      insecure: true,
    }
    datacenter = ENV['VCENTER_DATACENTER'] ||= '${{ secrets.VCENTER_DATACENTER }}'
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
      username: ENV['VCENTER_GUEST_USERNAME'] ||= '${{ secrets.VCENTER_GUEST_USERNAME }}',
      password: ENV['VCENTER_GUEST_PASSWORD'] ||= '${{ secrets.VCENTER_GUEST_PASSWORD }}',
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

  def execute_command(path, program_path, arguments)
    machine = get_machine(path)
    manager = @vim.serviceContent.guestOperationsManager
    auth = RbVmomi::VIM::NamePasswordAuthentication(machine_credentials)
    manager.authManager.ValidateCredentialsInGuest(vm: machine, auth: auth)
    pid = manager.processManager.StartProgramInGuest(vm: machine, auth: auth, spec: { programPath: program_path, arguments: arguments })
    with_retries(max_tries: 10,
                 max_sleep_seconds: 10,
                 rescue: NotFinished) do
      info = manager.processManager.ListProcessesInGuest(vm: machine, auth: auth, pids: [pid]).first
      raise NotFinished unless info.exitCode
      info
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

  def apply
    manifest = render.delete("\n")
    cmd = "bundle exec puppet apply --detailed-exitcodes -e \"#{manifest}\" --modulepath spec/fixtures/modules --libdir lib --debug"
    result = { output: [], exit_status: nil }

    Open3.popen2e(cmd) do |_stdin, stdout_err, wait_thr|
      while line = stdout_err.gets # rubocop:disable Lint/AssignmentInCondition
        result[:output].push(line)
        puts line
      end
      result[:exit_status] = wait_thr.value
    end

    result
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
  def self.shell(cmd)
    Open3.popen3(cmd) do |_stdin, stdout, stderr, wait_thr|
      @out = read_stream(stdout)
      @error = read_stream(stderr)
      @code = %r{(exit)(\s)(\d+)}.match(wait_thr.value.to_s)[3]
    end
    TestExecutor::Response.new(@out, @error, @code, cmd)
  end

  def self.read_stream(stream)
    result = ''
    while line = stream.gets # rubocop:disable Lint/AssignmentInCondition
      result << line if line.class == String
      puts line
    end
    result
  end

  # build and apply complex puppet resource commands
  # the arguement resource is the type of the resource
  # the opts hash must include a key 'name'
  def self.puppet_resource(resource, opts = {}, command_flags = '')
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
    cmd << " --libdir lib --modulepath spec/fixtures/modules #{command_flags}"
    # apply the command
    response = shell(cmd)
    response
  end
end

class TestExecutor::Response
  attr_reader :stdout, :stderr, :exit_code, :command

  def initialize(standard_out, standard_error, exit, cmd)
    @stdout = standard_out
    @stderr = standard_error
    @exit_code = exit
    @command = cmd
  end
end
