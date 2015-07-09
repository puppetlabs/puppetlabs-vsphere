require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'master_manipulator'

test_name 'CLOUD-372 - C68522 - vcenter.conf file has wrong VSPHERE_PASSWORD'
test_name 'CLOUD-372 - C68531 - vcenter.conf file missing VSPHERE_PASSWORD'

folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    agents.each do |agent|
      ensure_vm_is_absent(agent, "#{folder}/#{name}")
    end
  end
end

#test 1: creating a VM with wrong VCENTER_PASSWORD
step 'Exporting credentials with wrong VCENTER_SERVER value'
server    = ENV['VCENTER_SERVER']
user      = ENV['VCENTER_USER']
password  = 'wrong-vcenter-password'

local_files_root_path     = ENV['FILES'] || 'files'
vcenter_conf_template     = File.join(local_files_root_path, 'vcenter_conf.erb')
vcenter_conf_erb          = ERB.new(File.read(vcenter_conf_template)).result(binding)

step 'Overwrite vcenter.conf file on the agent node'
confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    confdir_path = on(agent, puppet('config', 'print', 'confdir')).stdout.rstrip
    create_remote_file(agent, "#{confdir_path}/vcenter.conf", vcenter_conf_erb)
  end
end

# Initialize the manifest template
path         = "#{folder}/#{name}"
status       = 'running'
source_path  = '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349'
memory       = 512
cpus         = 1
is_template  = 'false'
annotation   = 'VM with 1 CPU and 512MB RAM'

# Getting path for site.pp file on master node
environment_base_path = on(master, puppet('config', 'print', 'environmentpath')).stdout.rstrip
prod_env_site_pp_path = File.join(environment_base_path, 'production', 'manifests', 'site.pp')

# Getting the manifest template
local_files_root_path = ENV['FILES'] || 'files'
manifest_template     = File.join(local_files_root_path, 'manifest.erb')
manifest_erb          = ERB.new(File.read(manifest_template)).result(binding)

step "Manipulate the site.pp file on the master node"
site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine_block :except, :roles => %w{master dashboard database} do
  step "Creating VM from a template with name: '#{name}'"
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
      assert_match(/Error: Could not retrieve catalog from remote server: Error 400 on SERVER/, result.output, 'Test Failed')
    end
  end
end

#test 2: creating a VM with missing VCENTER_PASSWORD
step "Delete password param in vcenter.conf "
vcenter_conf_erb = vcenter_conf_erb.sub(/password.*/,"")

confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    confdir_path = on(agent, puppet('config', 'print', 'confdir')).stdout.rstrip
    create_remote_file(agent, "#{confdir_path}/vcenter.conf", vcenter_conf_erb)
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
      assert_match(/Error: Could not run: Puppet detected a problem with the information returned from vSphere when accessing vsphere_vm/, result.output, 'Test Failed')
      assert_match(/To use this module you must provide the following settings: password/, result.output, 'Test Failed')
    end
  end
end
