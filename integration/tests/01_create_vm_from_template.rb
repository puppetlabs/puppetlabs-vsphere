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
is_template  = 'false'

environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

#ERB Template
local_files_root_path = ENV['FILES'] || 'files'
manifest_template     = File.join(local_files_root_path, 'manifest.erb')
manifest_erb          = ERB.new(File.read(manifest_template)).result(binding)

teardown do
  agents.each do |agent|
    ensure_vm_is_absent(agent, path)
  end
end

step "Manipulate the site.pp file on the master node"
site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine :except, :roles => %w{master dashboard database}
step "Creating VM from a template on agent node:"
agents.each do |agent|
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
    expect_failure('Expected to fail due to CLOUD-355') do
      assert_match(/#{name}\]\/ensure: changed absent to present/, result.output, 'Failed to create VM from template')
    end
  end
end

step "Verify the VM has been successfully created in vCenter:"
# Once CLOUD-355 is fixed this will need to be re-enabled.
#vm_exists?(datacenter, "#{name}")
