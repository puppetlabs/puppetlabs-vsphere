Puppet::Type.newtype(:vsphere_machine) do
  @doc = 'type representing a virtual machine in VMWare vSphere'

  ensurable

  newparam(:name, namevar: true) do
    desc 'the name of the virtual machine'
    validate do |value|
      fail 'Virtual machines must have a name' if value == ''
    end
  end

  newparam(:template) do
    desc 'the template to use as the base for the new machine'
  end

  newproperty(:memory) do
    desc 'the amount of memory in MB to use for the machine'
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:cpus) do
    desc 'the number of CPUs to make available to the machine'
    def insync?(is)
      is.to_i == should.to_i
    end
  end

  newproperty(:vdc) do
    desc 'the virtual datacenter in which the machine resides'
  end

  newproperty(:folder) do
    desc 'the location of the machine'
  end
end
