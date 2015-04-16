require 'mustache'
require 'open3'
require 'fog'

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
    cmd = "bundle exec puppet apply --detailed-exitcodes -e \"#{manifest}\" --modulepath ../"
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

  def initialize
    server = ENV['VSPHERE_SERVER']
    user = ENV['VSPHERE_USER']
    password = ENV['VSPHERE_PASSWORD']
    hash = ENV['VSPHERE_HASH']
    version = '5.5'
    secure = false
    credentials = {
      :provider => 'vsphere',
      :vsphere_username => user ,
      :vsphere_password => password,
      :vsphere_server => server,
      :vsphere_ssl  => secure,
      :vsphere_expected_pubkey_hash => hash,
      :vsphere_rev  => version
    }
    @client = Fog::Compute.new(credentials)
  end

  def get_machines(name)
    @client.servers.find_all { |server| server.name == name }
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
    cmd << " #{command_flags}"
    # apply the command
    response = shell(cmd)
    response
  end

end

class TestExecutor::Response
  attr_reader :stdout , :stderr, :exit_code, :command

  def initialize(standard_out, standard_error, exit, cmd)
    @stdout = standard_out
    @stderr = standard_error
    @exit_code = exit
    @command = cmd
  end

end
