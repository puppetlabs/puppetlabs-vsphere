require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'rbvmomi'
require 'master_manipulator'

test_name 'CLOUD-282 - C64687 - Create vSphere VM from template'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)
path         = "#{folder}/#{name}"
status       = 'present'
source_path  = '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349'
memory       = '512'
cpus         = '1'
is_template  = 'false'
annotation   = 'Create VM from template'

environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

#ERB Template
local_files_root_path = ENV['FILES'] || 'files'
manifest_template     = File.join(local_files_root_path, 'manifest.erb')
manifest_erb          = ERB.new(File.read(manifest_template)).result(binding)

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    ensure_vm_is_absent(agent, path)
  end
end

# For PE 3.8.1 this is an alternative to the failed first run below
#on(master, puppet('agent', '-t', '--environment production'))

step "Manipulate the site.pp file on the master node"
site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine_block :except, :roles => %w{master dashboard database} do
  step 'Trigger agent/server sync on master to work around PE-10757'
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
    expect_failure('Expected to fail due to PE-10757') do
      assert_match(/#{name}\]\/ensure: changed absent to present/, result.output, 'Failed to create VM from template')
    end
  end


  step "Creating VM from a template on agent node"
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
    assert_match(/#{name}\]\/ensure: changed absent to present/, result.output, 'Failed to create VM from template')
  end
end

step "Verify the VM has been successfully created in vCenter"
vm_exists?(datacenter, name)
