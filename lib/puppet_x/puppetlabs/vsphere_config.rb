# frozen_string_literal: true

# The Puppet Extensions Module.
#
module PuppetX
  # PuppetLabs Module.
  module Puppetlabs
    # Vsphere configuration
    class VsphereConfig
      #   @param name
      #     The full path for the machine, including the datacenter identifier.
      #   @param envs
      #     environment variables
      REQUIRED = {
        names: [:host, :user, :password],
        envs: ['VCENTER_SERVER', 'VCENTER_USER', 'VCENTER_PASSWORD'],
      }.freeze

      # Creates instance variables and corresponding methods that return the
      # value of each instance variable. String arguments are converted to symbols.
      attr_reader :host, :user, :password, :datacenter, :insecure, :port, :ssl

      # default configuration file
      def default_config_file
        Puppet.initialize_settings unless Puppet[:confdir]
        File.join(Puppet[:confdir], 'vcenter.conf')
      end

      # initialize
      def initialize(config_file = nil)
        settings = process_environment_variables || process_config_file(config_file || default_config_file)
        if settings.nil?
          raise Puppet::Error, 'You must provide credentials in either environment variables or a config file.'
        else
          settings = settings.delete_if { |_k, v| v.nil? }
          missing = REQUIRED[:names] - settings.keys
          unless missing.empty?
            message = 'To use this module you must provide the following settings:'
            missing.each do |var|
              message += " #{var}"
            end
            raise Puppet::Error, message
          end
          @host = settings[:host]
          @user = settings[:user]
          @password = settings[:password]
          @datacenter = settings[:datacenter_name]
          @insecure = settings[:insecure].nil? ? true : settings[:insecure]
          @ssl = settings[:ssl].nil? ? true : settings[:ssl]
          @port = settings[:port]
        end
      end

      # process config file
      # @param
      #   file_path - The full path of the configuration file
      def process_config_file(file_path)
        file_present = File.file?(file_path)
        if file_present
          begin
            conf = ::Hocon::ConfigFactory.parse_file(file_path)
          rescue Hocon::ConfigError::ConfigParseError => e
            raise Puppet::Error, ''"Your configuration file at #{file_path} is invalid. The error from the parser is
#{e.message}"''
          end
          vsphere_config = conf.root.unwrapped['vcenter']
          required = REQUIRED[:names].map { |var| var.to_s }
          missing = required - vsphere_config.keys
          if missing.size < required.size
            {
              host: vsphere_config['host'],
              user: vsphere_config['user'],
              password: vsphere_config['password'],
              datacenter_name: vsphere_config['datacenter'],
              insecure: vsphere_config['insecure'],
              port: vsphere_config['port'],
              ssl: vsphere_config['ssl'],
            }
          else
            nil
          end
        else
          nil
        end
      end

      # process environment variables
      def process_environment_variables
        required = REQUIRED[:envs]
        missing = required - ENV.keys
        if missing.size < required.size
          {
            host: ENV['VCENTER_SERVER'],
            user: ENV['VCENTER_USER'],
            password: ENV['VCENTER_PASSWORD'],
            datacenter_name: ENV['VCENTER_DATACENTER'],
            insecure: ENV['VCENTER_INSECURE'],
            port: ENV['VCENTER_PORT'],
            ssl: ENV['VCENTER_SSL'],
          }
        else
          nil
        end
      end
    end
  end
end
