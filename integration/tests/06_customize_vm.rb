require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'rbvmomi'
require 'master_manipulator'

test_name 'CLOUD-283 - C64688 - Create a VM and then customize it in vSphere module'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)

# Initialize the manifest template
path         = "#{folder}/#{name}"
status       = 'running'
source_path  = '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349'
memory       = '512'
cpus         = '1'
is_template  = 'false'
annotation   = 'VM with 1 CPU and 512MB RAM'

# Getting path for site.pp file on master node
environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

# Getting the manifest template
local_files_root_path = ENV['FILES'] || 'files'
manifest_template     = File.join(local_files_root_path, 'manifest.erb')
manifest_erb          = ERB.new(File.read(manifest_template)).result(binding)

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    agents.each do |agent|
      ensure_vm_is_absent(agent, "#{folder}/#{name}")
    end
  end
end

step "Manipulate the site.pp file on the master node the first time"
site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

#Create a VM and customize it
confine_block :except, :roles => %w{master dashboard database} do
  step "Creating VM from a template with name: '/eng/integration/vm/#{name}'"
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/#{name}\]\/ensure: changed absent to running/, result.output, 'Failed to create VM from template')
    end
    step "Verify the VM has been successfully created in vCenter:"
    vm_exists?(datacenter, "#{name}")

    step "puppet source vsphere_vm: #{folder}/#{name} BEFORE being customized"
    on(agent, puppet('resource', 'vsphere_vm', "#{folder}/#{name}")) do |result|
      assert_match(/cpu.*#{cpus}/, result.output, 'Failed to create specified CPU')
      assert_match(/memory.*#{memory}/, result.output, 'Failed to create specified memory')
      puts result
    end

  end
end

# Modify the VM
step "Manipulate the site.pp file on the master node the second time"
# Modify manifest_erb file
memory       = '2048'
cpus          = '2'
annotation   = 'VM with 2 CPUs and 2GB RAM'

manifest_template = File.join(local_files_root_path, 'manifest.erb')
manifest_erb      = ERB.new(File.read(manifest_template)).result(binding)

site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine_block :except, :roles => %w{master dashboard database} do
  step "Customize the VM: '#{name}'"
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/memory: memory changed '512' to '2048'/, result.output, "Failed to customize the VM: '#{name}'")
      assert_match(/cpus: cpus changed '1' to '2'/, result.output, "Failed to customize the VM: '#{name}'")
      assert_match(/annotation: annotation changed.*VM with 2 CPU and 2GB RAM/, result.output, "Failed to customize the VM: '#{name}'")
    end
  end
  step "Verify the VM still exist in vCenter:"
  vm_exists?(datacenter, "#{name}")

  step "puppet source vsphere_vm: #{folder}/#{name} AFTER being customized"
  on(agent, puppet('resource', 'vsphere_vm', name)) do |result|
    assert_match(/cpu.*#{cpus}/, result.output, 'Failed to create specified CPU')
    assert_match(/memory.*#{memory}/, result.output, 'Failed to create specified memory')
    puts result
  end
end
