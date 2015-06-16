module PuppetX
  module Puppetlabs
    class VsphereConfig
      REQUIRED = {
        names: [:host, :user, :password],
        envs: ['VCENTER_SERVER', 'VCENTER_USER', 'VCENTER_PASSWORD'],
      }

      attr_reader :host, :user, :password, :datacenter, :insecure, :port, :ssl

      def default_config_file
        Puppet.initialize_settings unless Puppet[:confdir]
        File.join(Puppet[:confdir], 'vcenter.conf')
      end

      def initialize(config_file=nil)
        settings = process_environment_variables || process_config_file(config_file || default_config_file)
        if settings.nil?
          raise Puppet::Error, 'You must provide credentials in either environment variables or a config file.'
        else
          settings = settings.delete_if { |k, v| v.nil? }
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

      def process_config_file(file_path)
        file_present = File.file?(file_path)
        unless file_present
          nil
        else
          begin
            conf = ::Hocon::ConfigFactory.parse_file(file_path)
          rescue Hocon::ConfigError::ConfigParseError => e
            raise Puppet::Error, """Your configuration file at #{file_path} is invalid. The error from the parser is
#{e.message}"""
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
        end
      end

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
