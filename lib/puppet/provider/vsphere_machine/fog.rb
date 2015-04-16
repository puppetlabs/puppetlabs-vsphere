require 'fog'

Puppet::Type.type(:vsphere_machine).provide(:fog) do
  confine feature: :fog

  mk_resource_methods

  def self.client
    server = ENV['VSPHERE_SERVER']
    user = ENV['VSPHERE_USER']
    password = ENV['VSPHERE_PASSWORD']
    hash = ENV['VSPHERE_HASH']
    version = '5.5'
    secure = false
    credentials = {
      :provider => 'vsphere',
      :vsphere_username => user ,
      :vsphere_password => password,
      :vsphere_server => server,
      :vsphere_ssl  => secure,
      :vsphere_expected_pubkey_hash => hash,
      :vsphere_rev  => version
    }
    Fog::Compute.new(credentials)
  end

  def client
    self.class.client
  end

  def self.instances
    client.servers.collect do |machine|
      new(machine_to_hash(machine))
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name] # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.machine_to_hash(machine)
    {
      name: machine.name,
      memory: machine.memory_mb,
      cpus: machine.cpus,
      vdc: machine.datacenter,
      ensure: :present,
    }
  end

  def exists?
    Puppet.info("Checking if machine #{name} exists")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating machine #{name}")
    client.vm_clone({
      'datacenter'    => resource[:vdc],
      'template_path' => resource[:template],
      'name'          => name,
      'memoryMB'      => resource[:memory],
      'numCPUs'       => resource[:cpus],
      'dest_folder'   => resource[:folder],
    })
    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Deleting machine #{name}")
    machine = client.servers.find_all { |server| server.name == name }
    fail "Found more than one machine named #{name}" if machine.count != 1
    unless machine.first.power_state == 'poweredOff'
      machine.first.stop
      machine.first.wait_for { power_state == 'poweredOff' }
    end
    machine.first.destroy
    @property_hash[:ensure] = :absent
  end
end


