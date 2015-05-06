require 'puppet_x/puppetlabs/prefetch_error'
require 'puppet_x/puppetlabs/vsphere'


Puppet::Type.type(:vsphere_machine).provide(:rbvmomi, :parent => PuppetX::Puppetlabs::Vsphere) do
  confine feature: :rbvmomi

  mk_resource_methods

  read_only(:cpus, :memory)

  def self.instances
    begin
      find_vms_in_folder(datacenter.vmFolder).collect do |machine|
        new(machine_to_hash(machine)) unless machine.summary.config.template
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
    {
      name: "/#{name}",
      memory: machine.summary.config.memorySizeMB,
      cpus: machine.summary.config.numCpu,
      compute: compute,
      ensure: state,
      memory_reservation: machine.summary.config.memoryReservation,
      cpu_reservation: machine.summary.config.cpuReservation,
      number_ethernet_cards: machine.summary.config.numEthernetCards,
      power_state: machine.summary.runtime.powerState,
      tools_installer_mounted: machine.summary.runtime.toolsInstallerMounted,
      snapshot_disabled: machine.config.flags.snapshotDisabled,
      snapshot_locked: machine.config.flags.snapshotLocked,
      snapshot_power_off_behavior: machine.config.flags.snapshotPowerOffBehavior,
    }
  end

  def exists?
    Puppet.info("Checking if machine #{name} exists")
    @property_hash[:ensure] == :running || @property_hash[:ensure] == :stopped
  end

  def create(args={})
    Puppet.info("Creating machine #{name}")

    power_on = args[:stopped] == true ? false : true

    if resource[:template] && resource[:source_machine]
      raise Puppet::Error, "Cannot use both template and source_machine at the same time"
    elsif resource[:template]
      create_from_template(resource[:template], power_on)
    elsif resource[:source_machine]
      create_from_vm(resource[:source_machine], power_on)
    else
      raise Puppet::Error, "Template or source_machine not provided"
    end

    @property_hash[:ensure] = :present
  end

  def create_from_template(path, power_on)
    template = datacenter.find_vm(path)
    raise Puppet::Error, "No template found at #{path}" unless template

    pool = datacenter.find_compute_resource(resource[:compute]).resourcePool
    raise Puppet::Error, "No resource pool found for compute #{resource[:compute]}" unless pool

    relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool)
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :powerOn => power_on,
      :template => false)

    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
    clone_spec.config.numCPUs = resource[:cpus] if resource[:cpus]
    clone_spec.config.memoryMB = resource[:memory] if resource[:memory]

    template.CloneVM_Task(
      :folder => find_or_create_folder(datacenter.vmFolder, instance.folder),
      :name => instance.name,
      :spec => clone_spec).wait_for_completion
  end

  def create_from_vm(path, power_on)
    base_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(path)
    vm = datacenter.find_vm(base_machine.local_path)
    raise Puppet::Error, "No VM found at #{base_machine.local_path}" unless vm

    relocate_spec = RbVmomi::VIM.VirtualMachineRelocateSpec
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :powerOn  => power_on,
      :template => false)

    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
    clone_spec.config.numCPUs = resource[:cpus] if resource[:cpus]
    clone_spec.config.memoryMB = resource[:memory] if resource[:memory]

    vm.CloneVM_Task(
      :folder => find_or_create_folder(datacenter.vmFolder, instance.folder),
      :name   => instance.name,
      :spec   => clone_spec).wait_for_completion
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

  def destroy
    Puppet.info("Deleting machine #{name}")
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

end
