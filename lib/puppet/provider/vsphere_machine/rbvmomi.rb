require 'puppet_x/puppetlabs/prefetch_error'
require 'puppet_x/puppetlabs/vsphere'


Puppet::Type.type(:vsphere_machine).provide(:rbvmomi, :parent => PuppetX::Puppetlabs::Vsphere) do
  confine feature: :rbvmomi

  mk_resource_methods

  def self.instances
    begin
      find_vms_in_folder(datacenter.vmFolder).collect do |machine|
        new(machine_to_hash(machine))
      end.compact
    rescue StandardError => e
      raise PuppetX::Puppetlabs::PrefetchError.new(self.resource_type.name.to_s, e.message)
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.machine_to_hash(machine)
    name = machine.path.collect { |x| x[1] }.drop(1).join('/')
    resource_pool = machine.resourcePool
    compute = resource_pool ? resource_pool.parent.name : nil
    state = machine.runtime.powerState  == 'poweredOn' ? :running : :stopped
    hostname = machine.summary.guest.hostName
    extra_config = {}
    machine.config.extraConfig.map do |setting|
      extra_config[setting.key] = setting.value
    end

    {
      name: "/#{name}",
      memory: machine.summary.config.memorySizeMB,
      cpus: machine.summary.config.numCpu,
      compute: compute,
      template: machine.summary.config.template,
      ensure: state,
      memory_reservation: machine.summary.config.memoryReservation,
      cpu_reservation: machine.summary.config.cpuReservation,
      number_ethernet_cards: machine.summary.config.numEthernetCards,
      power_state: machine.summary.runtime.powerState,
      tools_installer_mounted: machine.summary.runtime.toolsInstallerMounted,
      snapshot_disabled: machine.config.flags.snapshotDisabled,
      snapshot_locked: machine.config.flags.snapshotLocked,
      snapshot_power_off_behavior: machine.config.flags.snapshotPowerOffBehavior,
      uuid: machine.summary.config.uuid,
      instance_uuid: machine.summary.config.instanceUuid,
      guest_ip: machine.guest_ip,
      hostname: hostname == '(none)' ? nil : hostname,
      extra_config: extra_config,
    }
  end

  def exists?
    Puppet.info("Checking if #{type_name} #{name} exists")
    @property_hash[:ensure] == :running || @property_hash[:ensure] == :stopped
  end

  def create(args={})
    Puppet.info("Creating #{type_name} #{name}")

    raise Puppet::Error, "Must provide a source machine or template to base the new machine on" unless resource[:source]

    base_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(resource[:source])
    vm = datacenter.find_vm(base_machine.local_path)
    raise Puppet::Error, "No machine found at #{base_machine.local_path}" unless vm

    if resource[:compute]
      pool = datacenter.find_compute_resource(resource[:compute]).resourcePool
      raise Puppet::Error, "No resource pool found for compute #{resource[:compute]}" unless pool
    else
      hosts = datacenter.hostFolder.children
      raise Puppet::Error, "No resource pool found for default datacenter" if hosts.empty?
      pool = hosts.first.resourcePool
    end

    power_on = args[:stopped] == true ? false : true
    power_on = false if is_template?
    relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool)
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :template => is_template?,
      :powerOn => power_on)

    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
    clone_spec.config.numCPUs = resource[:cpus] if resource[:cpus]
    clone_spec.config.memoryMB = resource[:memory] if resource[:memory]

    vm.CloneVM_Task(
      :folder => find_or_create_folder(datacenter.vmFolder, instance.folder),
      :name => instance.name,
      :spec => clone_spec).wait_for_completion

    @property_hash[:ensure] = :present
  end

  def flush
    if ! @property_hash.empty? and @property_hash[:ensure] != :absent 
      config_spec = RbVmomi::VIM.VirtualMachineConfigSpec
      config_spec.numCPUs = resource[:cpus] if resource[:cpus]
      config_spec.memoryMB = resource[:memory] if resource[:memory]
      if resource[:extra_config]
        config_spec.extraConfig = resource[:extra_config].map do |k,v|
          {:key => k, :value => v}
        end
      end

      if config_spec.props.count > 0
        power_on = running?
        stop if power_on
        machine.ReconfigVM_Task(:spec => config_spec).wait_for_completion
        start if power_on
      end
    end
  end

  def find_or_create_folder(root, parts)
    if parts.empty?
      root
    else
      part = parts.shift
      folder = root.find(part)
      folder = root.CreateFolder(:name => part) if folder.nil?
      find_or_create_folder(folder, parts)
    end
  end

  def unregister
    Puppet.info("Unregistering #{type_name} #{name}")
    stop if running?
    machine.UnregisterVM
    @property_hash[:ensure] = :unregistered
  end

  def destroy
    Puppet.info("Deleting #{type_name} #{name}")
    stop if running?
    machine.Destroy_Task.wait_for_completion
    @property_hash[:ensure] = :absent
  end

  def stop
    machine.PowerOffVM_Task.wait_for_completion
    @property_hash[:ensure] = :stopped
  end

  def start
    machine.PowerOnVM_Task.wait_for_completion
    @property_hash[:ensure] = :running
  end

  def running?
    machine.runtime.powerState  == 'poweredOn' ? true : false
  end

  private
    def machine
      vm = datacenter.find_vm(instance.local_path)
      raise Puppet::Error, "No virtual machine found at #{instance.local_path}" unless vm
      vm
    end

    def instance
      PuppetX::Puppetlabs::Vsphere::Machine.new(name)
    end

    def is_template?
      resource[:template].to_s == 'true'
    end

    def type_name
      is_template? ? "template" : "machine"
    end

end
