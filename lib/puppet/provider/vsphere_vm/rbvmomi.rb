require 'puppet_x/puppetlabs/prefetch_error'
require 'puppet_x/puppetlabs/vsphere'
require 'retries'

class UnableToLoadConfigurationError < StandardError
end

Puppet::Type.type(:vsphere_vm).provide(:rbvmomi, :parent => PuppetX::Puppetlabs::Vsphere) do
  confine feature: :rbvmomi
  confine feature: :hocon

  mk_resource_methods

  [ :cpus, :memory, :extra_config, :annotation ].each do |property|
    define_method("#{property}=") do |v|
      # if @property_hash[property] != v
        @property_hash[property] = v
        @property_hash[:flush_reboot] = true
      # end
    end
  end

  def self.instances
    begin
      result = nil
      benchmark(:debug, 'loaded list of VMs') do
        data = load_machine_info(datacenter_instance)
        if data[RbVmomi::VIM::VirtualMachine]
          result = data[RbVmomi::VIM::VirtualMachine].collect do |obj, machine|
            hash = nil
            benchmark(:debug, "loaded machine information for #{machine['name']}") do
              hash = hash_from_machine_data(obj, machine, data)
            end
            new(hash)
          end
        else
          result = []
        end
      end
      result
    rescue Timeout::Error, StandardError => e
      # put error in the debug log, as re-raising it below swallows the correct stack trace
      Puppet.debug(e.inspect)
      Puppet.debug(e.backtrace)

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

  def self.resource_pool_from_machine_data(machine, data)
    path_components = []
    i = data[RbVmomi::VIM::ResourcePool][machine['resourcePool']]

    while i
      path_components << i['name']
      if i.has_key? 'parent'
        if data[RbVmomi::VIM::ResourcePool].has_key?(i['parent'])
          i = data[RbVmomi::VIM::ResourcePool][i['parent']]
        elsif data[RbVmomi::VIM::ComputeResource] && data[RbVmomi::VIM::ComputeResource].has_key?(i['parent'])
          path_components.pop
          i = data[RbVmomi::VIM::ComputeResource][i['parent']]
        elsif data[RbVmomi::VIM::ClusterComputeResource] && data[RbVmomi::VIM::ClusterComputeResource].has_key?(i['parent'])
          # There's always a top-level "Resources" pool that we do not want to show
          path_components.pop
          i = data[RbVmomi::VIM::ClusterComputeResource][i['parent']]
        else
          i = nil
        end
      else
        i = nil
      end
    end
    '/' + path_components.reverse.join('/')
  end

  def self.hash_from_machine_data(obj, machine, data)
    path_components = []
    i = machine
    while i
      path_components << i['name']
      if i.has_key? 'parent'
        if data[RbVmomi::VIM::Folder].has_key? i['parent']
          i = data[RbVmomi::VIM::Folder][i['parent']]
        elsif data[RbVmomi::VIM::Datacenter].has_key? i['parent']
          i = data[RbVmomi::VIM::Datacenter][i['parent']]
        else
          i = nil
        end
      else
        i = nil
      end
    end
    name = '/' + path_components.reverse.join('/')


    property_mappings = {
      cpus: 'summary.config.numCpu',
      snapshot_disabled: 'config.flags.snapshotDisabled',
      snapshot_locked: 'config.flags.snapshotLocked',
      annotation: 'config.annotation',
      guest_os: 'config.guestFullName',
      snapshot_power_off_behavior: 'config.flags.snapshotPowerOffBehavior',
      memory: 'summary.config.memorySizeMB',
      template: 'summary.config.template',
      memory_reservation: 'summary.config.memoryReservation',
      cpu_reservation: 'summary.config.cpuReservation',
      number_ethernet_cards: 'summary.config.numEthernetCards',
      power_state: 'runtime.powerState',
      tools_installer_mounted: 'summary.runtime.toolsInstallerMounted',
      uuid: 'summary.config.uuid',
      instance_uuid: 'summary.config.instanceUuid',
      hostname: 'summary.guest.hostName',
      guest_ip: 'guest.ipAddress',
    }

    api_properties = Hash[property_mappings
      .select { |_, v| machine.has_key? v }
      .collect { |key, property_name|
        [key, machine[property_name]]
      }
    ]

    cpu_affinity = machine['config.cpuAffinity']
    memory_affinity = machine['config.memoryAffinity']

    curated_properties = {
      name: name,
      resource_pool: resource_pool_from_machine_data(machine, data),
      ensure: machine_state(machine['runtime.powerState']),
      hostname: api_properties['hostname'] == '(none)' ? nil : api_properties['hostname'],
      datacenter: data[RbVmomi::VIM::Datacenter].first.last['name'],
      drs_behavior: drs_behavior_from_machine_data(machine, data),
      memory_affinity: memory_affinity.respond_to?('affinitySet') ? memory_affinity.affinitySet : [],
      cpu_affinity: cpu_affinity.respond_to?('affinitySet') ? cpu_affinity.affinitySet : [],
      object: obj,
    }

    # While the machine is booting, no extra config is available.
    curated_properties[:extra_config] = Hash[machine['config.extraConfig'].collect { |setting| [setting.key, setting.value] }] if machine.has_key? 'config.extraConfig'

    api_properties.merge(about_info).merge(curated_properties)
  end

  def self.cluster_compute_from_machine_data(machine, data)
    focus = data[RbVmomi::VIM::ResourcePool][machine['resourcePool']]
    while focus and focus.class != RbVmomi::VIM::ClusterComputeResource
      if (focus.class == Hash && focus.has_key?('parent'))
        focus = focus['parent']
      elsif focus.respond_to? 'parent'
        focus = focus.parent
      else
        focus = nil
      end
    end
    focus
  end

  def self.drs_behavior_from_machine_data(machine, data)
    cluster_compute = cluster_compute_from_machine_data(machine, data)
    if cluster_compute
      config = data[RbVmomi::VIM::ClusterComputeResource][cluster_compute_from_machine_data(machine, data)]['configurationEx']
      override = config.drsVmConfig.find {|c| c.key.name == machine['name'] }
      if override
        override.behavior
      else
        config.drsConfig.defaultVmBehavior
      end
    end
  end

  def self.machine_state(power_state)
    case power_state
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
    raise Puppet::Error, "Must provide a source machine, template or datastore folder to base the machine on" unless resource[:source]
    if resource[:source_type] == :folder
      create_from_folder
    else
      create_from_path(args)
    end
  end

  def create_from_path(args)
    Puppet.info("Creating #{type_name} #{name}")
    base_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(resource[:source])
    vm = datacenter_instance.find_vm(base_machine.local_path)
    raise Puppet::Error, "No machine found at #{base_machine.local_path}" unless vm

    if resource[:resource_pool]
      path_components = resource[:resource_pool].split('/').select { |s| !s.empty? }
      compute_resource_name = path_components.shift
      compute_resource = datacenter_instance.find_compute_resource(compute_resource_name)
      # FM-6637 Search nested paths
      compute_resource = datacenter_instance.find_compute_resource(resource[:resource_pool]) unless compute_resource
      unless compute_resource
        cr = datacenter_instance.hostFolder.children.map do | folder |
            raise Puppet::Error, "No compute resource found named #{compute_resource_name}" unless folder.respond_to?('find')
            folder.find(compute_resource_name) or
            folder.children.map do | cluster |
                cluster.resourcePool.find(compute_resource_name)
            end
        end
        compute_resource = cr.flatten.pop
      end
      raise Puppet::Error, "No compute resource found named #{compute_resource_name}" unless compute_resource
      if path_components.empty?
        pool = compute_resource.resourcePool
      else
        pool = compute_resource.resourcePool.traverse path_components.join('/')
      end
      raise Puppet::Error, "No resource pool found named #{resource[:resource_pool]}" unless pool
    else
      hosts = datacenter_instance.hostFolder.children
      raise Puppet::Error, "No resource pool found for default datacenter" if hosts.empty?
      pool = hosts.first.resourcePool
    end

    # Use the given datastore by name, or find the first datastore in 
    # the destination cluster.
    datastore = if resource[:datastore]
      datacenter_instance.find_datastore(resource[:datastore])
    elsif resource[:resource_pool]
      compute_resource.datastore.first
    else
      datastore = datacenter_instance.datastore.first
    end 
    raise Puppet::Error, "No datastore found named #{resource[:datastore]}" unless datastore
    relocate_spec = if is_linked_clone?
      vm.add_delta_disk_layer_on_all_disks
      # although we wait for the previous task to complete I was able
      # to sometimes trigger a race condition. I didn't find a suitable
      # assertion to make but a small sleep appears to aleviate the issue
      sleep 5
      RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool, :diskMoveType => :moveChildMostDiskBacking)
    else
      RbVmomi::VIM.VirtualMachineRelocateSpec(:pool => pool, :datastore => datastore)
    end

    power_on = args[:stopped] == true ? false : true
    power_on = false if is_template?
    clone_spec = RbVmomi::VIM.VirtualMachineCloneSpec(
      :location => relocate_spec,
      :template => is_template?,
      :powerOn => power_on)

    if resource[:customization_spec]
      begin
        clone_spec.customization = vim.serviceContent.customizationSpecManager.GetCustomizationSpec({name: resource[:customization_spec]}).spec
      rescue RbVmomi::Fault => exception
        if exception.message.split(':').first == 'NotFound'
          raise Puppet::Error, "Customization specification #{resource[:customization_spec]} not found"
        else
          raise
        end
      end
    end

    if resource[:cpus] || resource[:memory] || resource[:annotation]
      Puppet.debug("adding VirtualMachineConfigSpec for #{type_name} #{name}")
      clone_spec.config = RbVmomi::VIM.VirtualMachineConfigSpec(deviceChange: [])
      clone_spec.config.numCPUs = resource[:cpus] if resource[:cpus] && resource[:cpus] != vm.summary.config.numCpu
      # Store the set values in @property_hash, so that flush can skip those values
      @property_hash[:cpus] = resource[:cpus]
      clone_spec.config.memoryMB = resource[:memory] if resource[:memory] && resource[:memory] != vm.summary.config.memorySizeMB
      @property_hash[:memory] = resource[:memory]
      clone_spec.config.annotation = resource[:annotation] if resource[:annotation] && resource[:annotation] != vm.config.annotation
      @property_hash[:annotation] = resource[:annotation]
      if resource[:extra_config]
        clone_spec.config.extraConfig = resource[:extra_config].map do |k,v|
          {:key => k, :value => v}
        end
        @property_hash[:extra_config] = resource[:extra_config].dup
      end
    end

    vm.CloneVM_Task(
      :folder => find_or_create_folder(datacenter_instance.vmFolder, instance.folder),
      :name => instance.name,
      :spec => clone_spec).wait_for_completion

    execute_command_on_machine if resource[:create_command]

    @property_hash[:ensure] = :present
  end

  def create_from_folder
    Puppet.info("Registering #{type_name} #{name}")

    base_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(resource[:name])
    template = resource[:template].to_s == 'true' || false
    vm_folder = resource[:source]
    vm_ext = template ? "vmtx" : "vmx"

    datastore = datacenter_instance.datastore.first
    raise Puppet::Error, "No datastore found for default datacenter" unless datastore

    if resource[:resource_pool]
      compute = datacenter_instance.find_compute_resource(resource[:resource_pool])
      raise Puppet::Error, "No resource pool found with name #{resource[:resource_pool]}" unless compute
      host = template ? compute.host.first : nil
      raise Puppet::Error, "No host system found for resource pool #{resource[:resource_pool]}" unless host
      pool = template ? nil : compute.resourcePool
      raise Puppet::Error, "No resource pool found for #{resource[:resource_pool]}" unless pool
    else
      hosts = datacenter_instance.hostFolder.children
      raise Puppet::Error, "No resource pool found for default datacenter" if hosts.empty?
      host = template ? hosts.first.host.first : nil
      pool = template ? nil : hosts.first.resourcePool
    end

    folder = find_or_create_folder(datacenter_instance.vmFolder, base_machine.folder)
    folder.RegisterVM_Task(
      :path       => "[#{datastore.name}] #{vm_folder}/#{vm_folder}.#{vm_ext}",
      :asTemplate => template,
      :pool       => pool,
      :host       => host
    ).wait_for_completion
  end

  def execute_command_on_machine
    new_machine = PuppetX::Puppetlabs::Vsphere::Machine.new(name)
    machine = datacenter_instance.find_vm(new_machine.local_path)
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

  # ensure that 'is' has all key/value pairs present in 'should'
  def extra_config_matches?(is, should)
    Hash[should.keys.collect { |k| [k, is[k]] } ] == should
  end

  def flush
    if ! @property_hash.empty? and @property_hash[:flush_reboot]
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
        do_reboot = running?
        if do_reboot
          Puppet.info("Stopping #{name} to apply configuration changes")
          stop
        end
        machine.ReconfigVM_Task(:spec => config_spec).wait_for_completion
        if do_reboot
          Puppet.info("Starting #{name} after applying configuration changes")
          start
        end
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

  def delete_from_disk
    Puppet.info("Deleting #{type_name} #{name}")
    machine.Destroy_Task.wait_for_completion
    @property_hash[:ensure] = :absent
  end

  def destroy
    if resource[:delete_from_disk].to_s == 'false'
      unregister
    else
      delete_from_disk
    end
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
    self.class.machine_state(machine['runtime.powerState'])
  end

  private
    def machine
      unless @property_hash[:object]
        benchmark(:debug, "fetched #{instance.local_path} info from vSphere") do
          vim_machine = datacenter_instance.find_vm(instance.local_path)
          data = self.class.load_machine_info(vim_machine)
          machine = data[RbVmomi::VIM::VirtualMachine][vim_machine]
          hash = self.class.hash_from_machine_data(vim_machine, machine, data)
          @property_hash[:object] = hash[:object]
        end
      end
      raise Puppet::Error, "No virtual machine found at #{instance.local_path}" unless @property_hash[:object]
      @property_hash[:object]
    end

    def instance
      @instance ||= PuppetX::Puppetlabs::Vsphere::Machine.new(name)
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
