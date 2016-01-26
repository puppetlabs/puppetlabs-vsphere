test_name "QA-1912 - C64678 - Install using 'puppet module install puppetlabs-vsphere' command"

# step 'Setting Staging Forge'
# stub_forge_on(master)
#
# step 'Install puppetlabs-vsphere module on master'
# on(master, puppet('module install puppetlabs-vsphere'))

step 'Install Vsphere Module'
proj_root = File.expand_path(File.join(File.dirname(__FILE__), '../../../'))
staging = { :module_name => 'puppetlabs-vsphere' }
local = { :module_name => 'vsphere', :source => proj_root, :target_module_path => master['distmoduledir'] }

# Check to see if module version is specified.
staging[:version] = ENV['MODULE_VERSION'] if ENV['MODULE_VERSION']

# in CI install from staging forge, otherwise from local
install_dev_puppet_module_on(master, options[:forge_host] ? staging : local)
