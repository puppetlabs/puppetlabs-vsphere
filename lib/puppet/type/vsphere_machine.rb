require_relative '../../puppet_x/puppetlabs/property/read_only'

Puppet::Type.newtype(:vsphere_machine) do
  @doc = 'Type representing a virtual machine in VMWare vSphere.'

  validate do
    fail "Cannot specify both template and source_vm paths" if self[:template] && self[:source_vm]
  end

  newproperty(:ensure) do
    newvalue(:present) do
      provider.create unless provider.exists?
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
      desired = :running if desired == :present
      current == desired ? current : "changed #{current} to #{desired}"
    end
    def insync?(is)
      is = :present if is == :running
      is.to_s == should.to_s
    end
  end

  newparam(:name, namevar: true) do
    desc 'The name of the virtual machine.'
    validate do |value|
      fail 'Virtual machine name should be a String' unless value.is_a? String
      fail 'Virtual machines must have a name' if value == ''
    end
  end

  newparam(:template) do
    desc 'The template to use as the base for the new machine.'
    validate do |value|
      fail 'Virtual machine template should be a String' unless value.is_a? String
    end
  end

  newparam(:source_vm) do
    desc 'The path to the VM to use as the base for the new machine.'
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

  read_only_properties = {
    memory_reservation: 'memoryReservation',
    cpu_reservation: 'cpuReservation',
    number_ethernet_cards: 'numEthernetCards',
    power_state: 'powerState',
    tools_installer_mounted: 'toolsInstallerMounted',
    snapshot_disabled: 'snapshotDisabled',
    snapshot_locked: 'snapshotLocked',
    snapshot_power_off_behavior: 'snapshotPowerOffBehavior',
  }

  read_only_properties.each do |property, value|
    newproperty(property, :parent => PuppetX::Property::ReadOnly) do
      desc "Information related to #{value} from the vSphere API."
    end
  end

end
