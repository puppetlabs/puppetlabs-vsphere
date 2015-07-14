require 'puppet_x/puppetlabs/vsphere_config'

module PuppetX
  module Puppetlabs
    class Vsphere < Puppet::Provider
      def self.read_only(*methods)
        methods.each do |method|
          define_method("#{method}=") do |v|
            fail "#{method} property is read-only once #{resource.type} created."
          end
        end
      end

      def self.config
        PuppetX::Puppetlabs::VsphereConfig.new
      end

      def self.vim
        credentials = {
          host: config.host,
          user: config.user,
          password: config.password,
          insecure: config.insecure,
          ssl: config.ssl,
        }
        credentials[:port] = config.port if config.port
        begin
          RbVmomi::VIM.connect credentials
        rescue SocketError => e
          raise Puppet::Error, "Unable to access vSphere. Check you have the correct value in VCENTER_SERVER. The error message from the API client was: #{e.message}"
        end
      end

      def self.datacenter
        dc = vim.serviceInstance.find_datacenter(config.datacenter)
        unless dc
          message = "Unable to find datacenter"
          message = message + " named #{config.datacenter} as specified in VCENTER_DATACENTER" if config.datacenter
          raise Puppet::Error, message
        end
        dc
      end

      def self.find_vms_in_folder(folder)
        vim.serviceContent.viewManager.CreateContainerView({
          container: folder,
          type: ['VirtualMachine'],
          recursive: true,
        }).view
      end

      private
        def datacenter
          self.class.datacenter
        end

        def vim
          self.class.vim
        end

    end

    class Vsphere::Machine
      attr_reader :name, :folder, :datacenter, :local_path

      def initialize(path)
        @name = path.split('/')[-1]
        @datacenter = path.split('/')[1]
        @folder = path.split('/')[3...-1]
        @local_path = "/#{path.split('/')[3..-1].join('/')}"
      end
    end

  end
end
