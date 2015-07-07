require 'master_manipulator'

test_name "QA-1912 - C64678 - Install using 'puppet module install puppetlabs-vsphere' command"

step 'Setting Staging Forge'
stub_forge_on(master)

step 'Install puppetlabs-vsphere module on master'
on(master, puppet('module install puppetlabs-vsphere'))

# Make rbvmomi and hocon available to JRuby for Puppet Server
pe_master_version = on(master, puppet('-V')).stdout.rstrip.to_f
(pe_master_version < 4.0)? (puppetServer_path= '/opt/puppet/bin/puppetserver') : (puppetServer_path = '/opt/puppetlabs/server/bin/puppetserver')
on(master, "#{puppetServer_path} gem install rbvmomi hocon")

step 'Restart Puppet Server'
restart_puppet_server(master)

# Install rbvmomi and hocon on master and agent nodes:
agents.each do |agent|
  pe_version = on(agent, puppet('-V')).stdout.rstrip.to_f
  (pe_version < 4.0)? (path= '/opt/puppet/bin/gem') : (path = '/opt/puppetlabs/puppet/bin/gem')

  step 'install rbvmomi and hocon gems'
  on(agent, "NOKOGIRI_USE_SYSTEM_LIBRARIES=1 #{path} install rbvmomi hocon")
end
