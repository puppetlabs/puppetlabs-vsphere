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

      def self.datacenter
        missing = ['VSPHERE_SERVER', 'VSPHERE_USER', 'VSPHERE_PASSWORD'] - ENV.keys
        unless missing.empty?
          message = 'To use this module you must provide the following Environment variables:'
          missing.each do |var|
            message += "\n#{var}"
          end
          raise Puppet::Error, message
        end

        credentials = {
          host: ENV['VSPHERE_SERVER'],
          user: ENV['VSPHERE_USER'],
          password: ENV['VSPHERE_PASSWORD'],
          insecure: true,
        }
        datacenter_name = ENV['VSPHERE_DATACENTER']
        vim = RbVmomi::VIM.connect credentials
        dc = vim.serviceInstance.find_datacenter(datacenter_name)
        unless dc
          message = "Unable to find datacenter"
          message = message + " named #{datacenter_name} as specified in VSPHERE_DATACENTER" if datacenter_name
          raise Puppet::Error, message
        end
        dc
      end

      def self.find_vms_in_folder(folder) # recursively go through a folder, dumping vm info
        folder.childEntity.collect do |child|
          if child.class == RbVmomi::VIM::Folder
            find_vms_in_folder(child)
          elsif child.class == RbVmomi::VIM::VirtualMachine
            child
          end
        end.flatten
      end

      private
        def datacenter
          self.class.datacenter
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
