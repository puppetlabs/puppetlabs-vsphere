test_name "QA-1912 - C64678 - Install using 'puppet module install puppetlabs-vsphere' command"

step 'Setting Staging Forge'
stub_forge_on(master)

step 'Install puppetlabs-vsphere module on master'
on(master, puppet('module install puppetlabs-vsphere'))

agents.each do |agent|
  pe_version = on(agent, puppet('-V')).stdout.rstrip.to_f
  (pe_version < 4.0)? (path= '/opt/puppet/bin/gem') : (path = '/opt/puppetlabs/puppet/bin/gem')
<<<<<<< HEAD

  # Work-around for CLOUD-366 (install nokogiri before installing rbvmomi)
  on(agent, "#{path} install nokogiri -- --use-system-libraries")

  step 'install rbvmomi and hocon gems'
=======
  step 'install rbvmomi and hocon gems'
  on(agent, "#{path} install nokogiri -- --use-system-libraries")
>>>>>>> 1021ae3c78528911e06a9b24e537a5f333d0d558
  on(agent, "#{path} install rbvmomi hocon")
end
