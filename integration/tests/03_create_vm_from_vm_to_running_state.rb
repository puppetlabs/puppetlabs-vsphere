require 'vsphere_helper'
require 'securerandom'
require 'rbvmomi'
require 'master_manipulator'

test_name 'CLOUD-291 - C84247 Create vSphere VM from an existing VM and to running state'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)
path         = "#{folder}/#{name}"
status       = 'stopped'
source_path  = '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349'
memory       = '512'
cpus         = '1'
is_template  = 'false'
annotation   = 'Create VM from template'

environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    ensure_vm_is_absent(agent, "#{folder}/#{name}")
    ensure_vm_is_absent(agent, "#{folder}/vm_from_vm_#{name}")
  end
end

step "Manipulate the site.pp file on the master node the first time"
site_pp = create_site_pp(master, :manifest => render_manifest(binding))
inject_site_pp(master, prod_env_site_pp_path, site_pp)

step "Creating VM from a template first:"
confine_block :except, :roles => %w{master dashboard database} do
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
    assert_match(/#{name}\]\/ensure: changed absent to stopped/, result.output, 'Failed to create VM from template')
  end
end

step "Verify the VM is in stopped  state in vCenter"
vm_powerstate?(datacenter, name, "poweredOff")

step "Manipulate the site.pp file on the master node the second time"
path              = "#{folder}/vm_from_vm_#{name}"
status            = 'running'
source_path       = "#{folder}/#{name}"
memory            = '512'
cpus              = '1'
is_template       = 'false'
annotation        = 'Create VM from VM and to running state'

site_pp = create_site_pp(master, :manifest => render_manifest(binding))
inject_site_pp(master, prod_env_site_pp_path, site_pp)

step "Creating VM from VM and to running state"
confine_block :except, :roles => %w{master dashboard database} do
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
    assert_match(/vm_from_vm_#{name}\]\/ensure: changed absent to running/, result.output, 'Failed to create VM from VM')
  end
end

step "Verify the VM has been successfully created in vCenter:"
vm_exists?(datacenter, "vm_from_vm_#{name}")

step "Verify the VM is in running state in vCenter"
vm_powerstate?(datacenter, "vm_from_vm_#{name}", "poweredOn")
