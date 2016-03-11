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
          @@vim ||= RbVmomi::VIM.connect credentials
        rescue SocketError => e
          raise Puppet::Error, "Unable to access vSphere. Check you have the correct value in VCENTER_SERVER. The error message from the API client was: #{e.message}"
        end
      end

      def self.datacenter_instance
        dc = vim.serviceInstance.find_datacenter(config.datacenter)
        unless dc
          message = "Unable to find datacenter"
          message = message + " named #{config.datacenter} as specified in VCENTER_DATACENTER" if config.datacenter
          raise Puppet::Error, message
        end
        dc
      end

      def self.about_info
        unless @about_info
          info = vim.serviceInstance.content.about
          @about_info = {
            vcenter_full_version: "#{info.version} build-#{info.build}",
            vcenter_name: info.licenseProductName,
            vcenter_uuid: info.instanceUuid,
            vcenter_version: info.licenseProductVersion,
          }
        end
        @about_info
      end

      # fetch all data connected to a VirtualMachine, Folder, Datacenter, or ResourcePool
      # returns all connected object as a hash of hashes with the Class and the ManagedEntityReference as keys.
      def self.load_machine_info(start_obj)
        data = {}
        load_machine_info_native(start_obj).each do |d|
          data[d.obj.class] ||= []
          data[d.obj.class] << [d.obj, Hash[d.propSet.map { |prop| [prop.name, prop.val] }]]
        end
        data.each do |klass, objlist|
          data[klass] = Hash[objlist]
        end
        data
      end

      # runs the underlying native query to RbVmomi API for load_machine_info
      def self.load_machine_info_native(start_obj)
        filter_spec = RbVmomi::VIM.PropertyFilterSpec(
          :objectSet => [
            {
              :obj => start_obj,
              :skip => false,
              :selectSet => [
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitVMsFolder',
                  :type => 'VirtualMachine',
                  :path => 'parent',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitFolderParents'),
                  ]
                ),
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitFolderParents',
                  :type => 'Folder',
                  :path => 'parent',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitFolderParents'),
                  ]
                ),
              ],
            },
            {
              :obj => start_obj,
              :skip => false,
              :selectSet => [
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitVMs',
                  :type => 'Datacenter',
                  :path => 'vmFolder',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitFolders'),
                  ]
                ),
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitFolders',
                  :type => 'Folder',
                  :path => 'childEntity',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitFolders'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitVMsResourcePools'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolParents'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolCCRs'),
                  ]
                ),
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitVMsResourcePools',
                  :type => 'VirtualMachine',
                  :path => 'resourcePool',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitVMsResourcePools'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolParents'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolCCRs'),
                  ]
                ),
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitResourcePoolParents',
                  :type => 'ResourcePool',
                  :path => 'parent',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolParents'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolCCRs'),
                  ]
                ),
                RbVmomi::VIM.TraversalSpec(
                  :name => 'VisitResourcePoolCCRs',
                  :type => 'ClusterComputeResource',
                  :path => 'parent',
                  :skip => false,
                  :selectSet => [
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolParents'),
                    RbVmomi::VIM.SelectionSpec(:name => 'VisitResourcePoolCCRs'),
                  ]
                ),
              ]
            }
          ],
          :propSet => [{
              :type => 'Datacenter',
              :pathSet => [
                'name',
              ]
            },
            {
              :type => 'Folder',
              :pathSet => [
                'name',
                'parent',
              ]
            },
            {
              :type => 'VirtualMachine',
              :pathSet => [
                'name',
                'parent',
                'resourcePool',
                'guest.ipAddress',
                'summary.config.instanceUuid',
                'summary.config.numCpu',
                'config.extraConfig',
                'config.flags.snapshotDisabled',
                'config.flags.snapshotLocked',
                'config.annotation',
                'config.guestFullName',
                'config.flags.snapshotPowerOffBehavior',
                'config.cpuAffinity',
                'config.memoryAffinity',
                'summary.config.memorySizeMB',
                'summary.config.template',
                'summary.config.memoryReservation',
                'summary.config.cpuReservation',
                'summary.config.numEthernetCards',
                'summary.runtime.powerState',
                'summary.runtime.toolsInstallerMounted',
                'summary.config.uuid',
                'summary.config.instanceUuid',
                'summary.guest.hostName',
                'runtime.powerState',
                'runtime.host',
              ]
            },
            {
              :type => 'ResourcePool',
              :pathSet => [
                'name',
                'parent',
              ]
            },
            {
              :type => 'ComputeResource',
              :pathSet => [
                'name',
                'parent',
                'configurationEx',
              ]
            },
            {
              :type => 'ClusterComputeResource',
              :pathSet => [
                'name',
                'parent',
                'configurationEx',
              ]
            },
          ]
        )
        vim.propertyCollector.RetrieveProperties(:specSet => [filter_spec])
      end

      private
        def datacenter_instance
          self.class.datacenter_instance
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
