require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'rbvmomi'
require 'master_manipulator'

test_name 'CLOUD-291 - C84247 Create vSphere VM from an existing VM and to running state'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)
path         = "#{folder}/#{name}"
status       = 'stopped'
source_path  = '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349'
is_template  = 'false'

environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

#ERB Template
local_files_root_path = ENV['FILES'] || 'files'
manifest_template     = File.join(local_files_root_path, 'manifest.erb')
manifest_erb          = ERB.new(File.read(manifest_template)).result(binding)

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    agents.each do |agent|
      ensure_vm_is_absent(agent, "#{folder}/#{name}")
      ensure_vm_is_absent(agent, "#{folder}/vm_from_vm_#{name}")
    end
  end
end

step "Manipulate the site.pp file on the master node the first time"
site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

step "Creating VM from a template first:"
confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/#{name}\]\/ensure: changed absent to stopped/, result.output, 'Failed to create VM from template')
    end
  end
end
step "Verify the VM is in stopped  state in vCenter"
machine_powerstate?(datacenter, name, "poweredOff")

step "Manipulate the site.pp file on the master node the second time"
# Modify manifest_erb file
path              = "#{folder}/vm_from_vm_#{name}"
status            = 'running'
source_path       = "#{folder}/#{name}"
is_template       = 'false'
manifest_template = File.join(local_files_root_path, 'manifest.erb')
manifest_erb      = ERB.new(File.read(manifest_template)).result(binding)

site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine_block :except, :roles => %w{master dashboard database} do
  step "Creating VM from VM and to running state"
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/vm_from_vm_#{name}\]\/ensure: changed absent to running/, result.output, 'Failed to create VM from VM')
    end
  end
end

step "Verify the VM has been successfully created in vCenter:"
vm_exists?(datacenter, "vm_from_vm_#{name}")

step "Verify the VM is in running state in vCenter"
machine_powerstate?(datacenter, name, "poweredOn")
