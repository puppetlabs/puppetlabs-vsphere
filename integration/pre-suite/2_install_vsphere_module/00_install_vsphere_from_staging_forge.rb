test_name "QA-1912 - C64678 - Install using 'puppet module install puppetlabs-vsphere' command"

step 'Setting Staging Forge'
stub_forge_on(master)

step 'Install puppetlabs-vsphere module on master'
on(master, puppet('module install puppetlabs-vsphere'))
