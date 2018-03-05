require_relative '../../puppet_x/puppetlabs/property/read_only'

Puppet::Type.newtype(:vsphere_vm) do
  @doc = 'Type representing a virtual machine in VMware vSphere.'

  validate do
    if self[:template].to_s == 'true'
      required = []
      required << 'resource_pool' if self[:resource_pool]
      required << 'cpus' if self[:cpus]
      required << 'memory' if self[:memory]
      fail "Cannot provide the following properties for a template: #{required.join(', ')}" unless required.empty?
      fail 'Templates can only be absent or present.' unless self[:ensure] =~ /^(absent|present)$/
    end
  end

  newproperty(:ensure) do
    defaultto :present
    newvalue(:present) do
      provider.create unless provider.exists?
    end
    newvalue(:absent) do
      if provider.exists?
        case provider.current_state
        when :running
          provider.stop
        when :suspended
          provider.start
          provider.stop
        end
        provider.destroy
      end
    end
    newvalue(:running) do
      if provider.exists?
        provider.start unless provider.running?
      else
        provider.create
      end
    end
    newvalue(:reset) do
      if provider.exists?
        case provider.current_state
        when :running
          provider.reset
        when :suspended, :stopped
          provider.start
        else
          fail "Cannot reset machine when in state #{provider.current_state}"
        end
      end
    end
    newvalue(:suspended) do
      if provider.exists?
        case provider.current_state
        when :running
          provider.suspend if provider.running?
        when :stopped, :suspended, :unregistered
          fail "Cannot suspend when machine is #{provider.current_state}."
        else
          fail 'Cannot suspend, machine state is unknown.'
        end
      end
    end
    newvalue(:stopped) do
      if provider.exists?
        case provider.current_state
        when :running
          provider.stop
        when :suspended
          provider.start
          provider.stop
        else
          fail 'Cannot stop, machine state is unknown.'
        end
      else
        provider.create({stopped: true})
      end
    end
    def change_to_s(current, desired)
      current = :running if current == :present and self[:template].to_s != 'true'
      desired = current if desired == :present and current != :absent
      current == desired ? current : "changed #{current} to #{desired}"
    end
    def insync?(is)
      is.to_s == should.to_s or
        (is.to_s == 'absent' and should.to_s == 'unregistered') or
        (is.to_s == 'running' and should.to_s == 'present' ) or
        (is.to_s == 'stopped' and should.to_s == 'present' )
    end
  end

  newparam(:name, namevar: true) do
    desc 'The name of the virtual machine.'
    validate do |value|
      fail 'Virtual machine name should be a String' unless value.is_a? String
      fail 'Virtual machines must have a name' if value == ''
      fail 'The last part of the path should be no more than 80 characters long' if value.split('/')[-1].size > 80
    end
  end

  newparam(:source) do
    desc 'The path to an existing machine or template to use as the base for the new machine or the name of the folder of the vm to register.'
    validate do |value|
      fail 'Virtual machine source should be a String' unless value.is_a? String
    end
  end

  newparam(:source_type) do
    desc 'The type of the source provided. Acceptable values are vm, template, or folder.'
    defaultto :vm
    newvalues(:vm, :template, :folder)
  end

  newparam(:delete_from_disk) do
    desc 'Whether or not to delete this VM from disk or unregister it from inventory.'
    defaultto :true
    newvalues(:true, :false)
  end

  newparam(:datastore) do
    desc 'The name of the datastore with which to associate the virtual machine. This is only appliciable when cloning a VM.'
    validate do |value|
      fail 'Virtual machine datastore should be a String' unless value.is_a? String
    end
  end

  newproperty(:memory) do
    desc 'The amount of memory in MB to use for the machine.'
    def insync?(is)
      is.to_i == should.to_i
    end
    validate do |value|
      fail 'Virtual machine memory should be an Integer' unless value.to_i.to_s == value.to_s
      fail 'Virtual machine memory should be greater than 0' unless value.to_i > 0
    end
  end

  newproperty(:cpus) do
    desc 'The number of CPUs to make available to the machine.'
    def insync?(is)
      is.to_i == should.to_i
    end
    validate do |value|
      fail 'Virtual machine cpus should be an Integer' unless value.to_i.to_s == value.to_s
      fail 'Virtual machine cpus should be greater than 0' unless value.to_i > 0
    end
  end

  newproperty(:resource_pool) do
    desc 'The name of the resource pool with which to associate the virtual machine.'
    validate do |value|
      fail 'Virtual machine resource_pool should be a String' unless value.is_a? String
      fail 'Virtual machine resource_pool may not contain slashes if it doesn\'t start with one' if value =~ %r{^[^/]+/}
      warning 'Virtual machine resource_pool should be a fully qualified resource pool path' unless value[0] == '/'
    end

    munge do |value|
      unless value[0] == '/'
        value = "/#{value}"
      end
      value
    end
  end

  newproperty(:annotation) do
    desc 'A user provided description of the machine.'
    validate do |value|
      fail 'Virtual machine annotation should be a String' unless value.is_a? String
    end
  end

  newproperty(:template) do
    desc 'Whether or not this machine is a template.'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end


  read_only_properties = {
    cpu_reservation: 'cpuReservation',
    datacenter: 'datacenter',
    guest_ip: 'ipAddress',
    guest_os: 'guestFullName',
    hostname: 'hostName',
    instance_uuid: 'instanceUuid',
    memory_reservation: 'memoryReservation',
    number_ethernet_cards: 'numEthernetCards',
    power_state: 'powerState',
    snapshot_disabled: 'snapshotDisabled',
    snapshot_locked: 'snapshotLocked',
    snapshot_power_off_behavior: 'snapshotPowerOffBehavior',
    tools_installer_mounted: 'toolsInstallerMounted',
    uuid: 'uuid',
    vcenter_full_version: 'AboutInfo.version and AboutInfo.build',
    vcenter_name: 'AboutInfo.licenseProductName',
    vcenter_uuid: 'AboutInfo.instanceUuid',
    vcenter_version: 'AboutInfo.licenseProductVersion',
    drs_behavior: 'drsConfig and drsVmConfig',
    memory_affinity: 'memoryAffinity',
    cpu_affinity: 'cpuAffinity',
  }

  read_only_properties.each do |property, value|
    newproperty(property, :parent => PuppetX::Property::ReadOnly) do
      desc "Information related to #{value} from the vSphere API."
    end
  end

  newproperty(:extra_config) do
    desc 'Additional configuration information for the virtual machine.'
    validate do |value|
      fail 'Virtual machine extra_config should be a Hash' unless value.is_a? Hash
    end
    def insync?(is)
      diff = is.merge(should)
      diff == is
    end
  end

  newparam(:customization_spec) do
    desc 'Applies this pre-existing customization specification at clone time to the newly built VM.'
    validate do |value|
      fail 'Virtual machine customization_spec should be a String' unless value.is_a? String
    end
  end

  newparam(:linked_clone) do
    desc 'When creating the machine whether it should be a linked clone or not.'
    defaultto :false
    newvalues(:true, :'false')
    def insync?(is)
      is.to_s == should.to_s
    end
  end

  # create_command => {
  #   command =>
  #   arguments =>
  #   working_directory =>
  #   user =>
  #   password =>
  # }
  newparam(:create_command) do
    desc 'Command to run on the machine when it is first created.'
    validate do |value|
      fail 'create_command should be a Hash' unless value.is_a? Hash
      required = ['command', 'user', 'password']
      missing = required - value.keys.map(&:to_s)
      unless missing.empty?
        fail "for create_command you are missing the following keys: #{missing.join(',')}"
      end
      ['command', 'user', 'password', 'working_directory', 'arguments'].each do |key|
        if value[key]
          fail "#{key} for create_command should be a String" unless value[key].is_a? String
        end
      end
    end
  end

  autorequire(:vsphere_vm) do
    self[:source]
  end

end
