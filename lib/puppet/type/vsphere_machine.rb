require_relative '../../puppet_x/puppetlabs/property/read_only'

Puppet::Type.newtype(:vsphere_machine) do
  @doc = 'Type representing a virtual machine in VMware vSphere.'

  validate do
    if self[:template].to_s == 'true'
      fail 'Cannot provide compute for a template.' if self[:compute]
      fail 'Templates can only be absent, present or unregistered.' unless self[:ensure] =~ /^(absent|present|unregistered)$/
    end
  end

  newproperty(:ensure) do
    defaultto :present
    newvalue(:present) do
      provider.create unless provider.exists?
    end
    newvalue(:unregistered) do
      provider.unregister if provider.exists?
    end
    newvalue(:absent) do
      provider.destroy if provider.exists?
    end
    newvalue(:running) do
      if provider.exists?
        provider.start unless provider.running?
      else
        provider.create
      end
    end
    newvalue(:stopped) do
      if provider.exists?
        provider.stop if provider.running?
      else
        provider.create({stopped: true})
      end
    end
    def change_to_s(current, desired)
      current = :running if current == :present
      desired = current if desired == :present
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
    end
  end

  newparam(:source) do
    desc 'The path to an existing machine or template to use as the base for the new machine.'
    validate do |value|
      fail 'Virtual machine path should be a String' unless value.is_a? String
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

  newproperty(:compute) do
    desc 'The name of the cluster compute resource with which to associate the virtual machine.'
    validate do |value|
      fail 'Virtual machine compute should be a String' unless value.is_a? String
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
    memory_reservation: 'memoryReservation',
    cpu_reservation: 'cpuReservation',
    number_ethernet_cards: 'numEthernetCards',
    power_state: 'powerState',
    tools_installer_mounted: 'toolsInstallerMounted',
    snapshot_disabled: 'snapshotDisabled',
    snapshot_locked: 'snapshotLocked',
    snapshot_power_off_behavior: 'snapshotPowerOffBehavior',
    guest_ip: 'ipAddress',
    uuid: 'uuid',
    instance_uuid: 'instanceUuid',
    hostname: 'hostName',
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

  autorequire(:vsphere_machine) do
    self[:source]
  end

end
