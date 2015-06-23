test_name "QA-1912 - C64678 - Install using 'puppet module install puppetlabs-vsphere' command"

step 'Setting Staging Forge'
stub_forge_on(master)

step 'Install puppetlabs-vsphere module on master'
on(master, puppet('module install puppetlabs-vsphere'))

agents.each do |agent|
  pe_version = on(agent, puppet('-V')).stdout.rstrip.to_f
  (pe_version < 4.0)? (path= '/opt/puppet/bin/gem') : (path = '/opt/puppetlabs/puppet/bin/gem')
  step 'install rbvmomi and hocon gems'
  on(agent, "#{path} install nokogiri -- --use-system-libraries")
  on(agent, "#{path} install rbvmomi hocon")
end
