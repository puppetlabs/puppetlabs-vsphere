require 'mustache'
require 'open3'
require 'rbvmomi'
require 'retries'

# This exception is used to signal expected continuations when waiting for events on the vCenter
class NotFinished < Exception
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
    manifest = self.render.gsub("\n", '')
    cmd = "bundle exec puppet apply --detailed-exitcodes -e \"#{manifest}\" --modulepath spec/fixtures/modules --libdir lib --debug"
    result = { output: [], exit_status: nil }

    Open3.popen2e(cmd) do |stdin, stdout_err, wait_thr|
      while line = stdout_err.gets
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
    hash.map { |k, v| { :k => k, :v => v }}
  end

  # necessary to build like [{ :values => Array }] rather than [[]] when there
  # are nested hashes, for the sake of Mustache being able to render
  # otherwise, simply return the item
  def self.to_generalized_array_list(arr)
    arr.map do |item|
      if item.class == Hash
        {
          :values => to_generalized_hash_list(item)
        }
      else
        item
      end
    end
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
    if machine
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
                 rescue: NotFinished,
                ) do
      begin
        manager.authManager.ValidateCredentialsInGuest(vm: machine, auth: auth)
        manager.processManager.ListProcessesInGuest(vm: machine, auth: auth)
      rescue RbVmomi::Fault => exception
        if exception.message.split(':').first == 'GuestOperationsUnavailable'
          raise NotFinished.new
        else
          raise
        end
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
                 rescue: NotFinished,
                ) do
      info = manager.processManager.ListProcessesInGuest(vm: machine, auth: auth, pids: [pid]).first
      raise NotFinished.new unless info.exitCode
      info
    end
  end
end

class TestExecutor

  def self.shell(cmd)
    Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
      @out = read_stream(stdout)
      @error = read_stream(stderr)
      @code = /(exit)(\s)(\d+)/.match(wait_thr.value.to_s)[3]
    end
    TestExecutor::Response.new(@out, @error, @code, cmd)
  end

  def self.read_stream(stream)
    result = String.new
    while line = stream.gets
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
    options = String.new
    opts.each do |k,v|
      if k.to_s == 'name'
        @name = v
      else
        options << "#{k.to_s}=#{v.to_s} "
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
