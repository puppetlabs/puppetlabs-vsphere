require 'puppet_x/puppetlabs/prefetch_error'
require 'puppet_x/puppetlabs/vsphere'
require 'retries'


Puppet::Type.type(:vsphere_machine).provide(:rbvmomi, :parent => PuppetX::Puppetlabs::Vsphere) do
  confine feature: :rbvmomi
  confine feature: :hocon

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
    resource_pool = resource_pool ? resource_pool.parent.name : nil
    state = machine_state(machine)
    hostname = machine.summary.guest.hostName
    extra_config = {}
    machine.config.extraConfig.map do |setting|
      extra_config[setting.key] = setting.value
    end

    {
      name: "/#{name}",
      memory: machine.summary.config.memorySizeMB,
      cpus: machine.summary.config.numCpu,
      resource_pool: resource_pool,
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
      annotation: machine.config.annotation,
    }
  end

  def self.machine_state(vm)
    case vm.runtime.powerState
    when 'poweredOn'
      :running
    when 'poweredOff'
      :stopped
    when 'suspended'
      :suspended
    else
      :unknown
    end
  end

  def exists?
    Puppet.info("Checking if #{type_name} #{name} exists")
    @property_hash[:ensure] and @property_hash[:ensure] != :absent
  end

  def create(args={})
    Puppet.info("Creating #{type_name} #{name}")

    raise Puppet::Error, "Must provide a source machine or template to base the new machine on" unless resource[:source]

    base_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(resource[:source])
    vm = datacenter.find_vm(base_machine.local_path)
    raise Puppet::Error, "No machine found at #{base_machine.local_path}" unless vm

    if resource[:resource_pool]
      pool = datacenter.find_compute_resource(resource[:resource_pool]).resourcePool
      raise Puppet::Error, "No resource pool found for #{resource[:resouce_pool]}" unless pool
    else
      hosts = datacenter.hostFolder.children
      raise Puppet::Error, "No resource pool found for default datacenter" if hosts.empty?
      pool = hosts.first.resourcePool
    end

    relocate_spec = if is_linked_clone?
      vm.add_delta_disk_layer_on_all_disks
      # although we wait for the previous task to complete I was able
      # to sometimes trigger a race condition. I didn't find a suitable
      # assertion to make but a small sleep appears to aleviate the issue
      sleep 5
      RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool, :diskMoveType => :moveChildMostDiskBacking)
    else
      RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool)
    end

    power_on = args[:stopped] == true ? false : true
    power_on = false if is_template?
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :template => is_template?,
      :powerOn => power_on)

    clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
    clone_spec.config.numCPUs = resource[:cpus] if resource[:cpus]
    clone_spec.config.memoryMB = resource[:memory] if resource[:memory]
    clone_spec.config.annotation = resource[:annotation] if resource[:annotation]

    vm.CloneVM_Task(
      :folder => find_or_create_folder(datacenter.vmFolder, instance.folder),
      :name => instance.name,
      :spec => clone_spec).wait_for_completion

    execute_command_on_machine if resource[:create_command]

    @property_hash[:ensure] = :present
  end

  def execute_command_on_machine
    new_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(name)
    machine = datacenter.find_vm(new_machine.local_path)
    machine_credentials = {
      interactiveSession: false,
      username: resource[:create_command]['user'],
      password: resource[:create_command]['password'],
    }
    manager = vim.serviceContent.guestOperationsManager
    auth = RbVmomi::VIM::NamePasswordAuthentication(machine_credentials)
    handler = Proc.new do |exception, attempt_number, total_delay|
      Puppet.debug("#{exception.message}; retry attempt #{attempt_number}; #{total_delay} seconds have passed")
      # All exceptions in RbVmomi are RbVmomi::Fault, rather than the actual API exception
      # The actual exceptions come out in the message, so we parse them out
      case exception.message.split(':').first
      when 'GuestComponentsOutOfDate'
        raise Puppet::Error, 'VMware Tools is out of date on the guest machine'
      when 'InvalidGuestLogin'
        raise Puppet::Error, 'Incorrect credentials for the guest machine'
      when 'OperationDisabledByGuest'
        raise Puppet::Error, 'Remote access is disabled on the guest machine'
      when 'OperationNotSupportedByGuest'
        raise Puppet::Error, 'Remote access is not supported by the guest operating system'
      end
    end
    arguments = resource[:create_command].has_key?('arguments') ? resource[:create_command]['arguments'] : ''
    working_directory = resource[:create_command].has_key?('working_directory') ? resource[:create_command]['working_directory'] : '/'
    spec = RbVmomi::VIM::GuestProgramSpec(
      programPath: resource[:create_command]['command'],
      arguments: arguments,
      workingDirectory: working_directory,
    )
    with_retries(:max_tries => 10,
                 :handler => handler,
                 :base_sleep_seconds => 5,
                 :max_sleep_seconds => 15,
                 :rescue => RbVmomi::Fault) do
      manager.authManager.ValidateCredentialsInGuest(vm: machine, auth: auth)
      response = manager.processManager.StartProgramInGuest(vm: machine, auth: auth, spec: spec)
      Puppet.info("Ran #{resource[:create_command]['command']}, started with PID #{response}")
    end
  end

  def flush
    if ! @property_hash.empty? and @property_hash[:ensure] != :absent
      config_spec = RbVmomi::VIM.VirtualMachineConfigSpec
      config_spec.numCPUs = resource[:cpus] if resource[:cpus]
      config_spec.memoryMB = resource[:memory] if resource[:memory]
      config_spec.annotation = resource[:annotation] if resource[:annotation]
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
    machine.UnregisterVM
    @property_hash[:ensure] = :unregistered
  end

  def destroy
    Puppet.info("Deleting #{type_name} #{name}")
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

  def suspend
    machine.SuspendVM_Task.wait_for_completion
    @property_hash[:ensure] = :suspended
  end

  def reset
    machine.ResetVM_Task.wait_for_completion
    @property_hash[:ensure] = :running
  end

  def running?
    current_state == :running
  end

  def stopped?
    current_state == :stopped
  end

  def suspended?
    current_state == :suspended
  end

  def unknown?
    current_state == :unknown
  end

  def current_state
    self.class.machine_state(machine)
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

    def is_linked_clone?
      resource[:linked_clone].to_s == 'true'
    end

    def type_name
      is_template? ? "template" : "machine"
    end

end
