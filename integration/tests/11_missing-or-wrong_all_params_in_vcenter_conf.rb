require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'master_manipulator'

test_name 'CLOUD-380 - C88650 - vcenter.conf file has wrong values for all params'
test_name 'CLOUD-380 - C64701 - vcenter.conf file missing all credentials (empty file)'
test_name 'CLOUD-380 - C88649 - There is no vcenter.conf file on the agent'

folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    agents.each do |agent|
      ensure_vm_is_absent(agent, "#{folder}/#{name}")
    end
  end
end

# Test 1: Creating a VM with all wrong values in vcenter.conf file
step 'Exporting credentials with all wrong values in vcenter.conf file'
server    = 'wrong-vcenter-server'
user      = 'wrong-vcenter-user'
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

# Test 2: Creating a VM with file vcenter.conf is empty
step "Delete all params in vcenter.conf "
File.truncate(vcenter_conf_erb, 0)
puts "After truncate: #{vcenter_conf_erb}"

confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    confdir_path = on(agent, puppet('config', 'print', 'confdir')).stdout.rstrip
    step "Create and empty #{confdir_path}/vcenter.conf file:"
    create_remote_file(agent, "#{confdir_path}/vcenter.conf", vcenter_conf_erb)
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
      puts "cat #{confdir_path}/vcenter.conf on agent"
      on(agent, "cat #{confdir_path}/vcenter.conf")
      assert_match(/Error: Could not run: Puppet detected a problem with the information returned from vSphere when accessing vsphere_vm/, result.output, 'Test Failed')
      assert_match(/To use this module you must provide the following settings: host/, result.output, 'Test Failed')
    end
  end
end

# Test 3: Creating VM without vcenter.conf file
confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    confdir_path = on(agent, puppet('config', 'print', 'confdir')).stdout.rstrip
    step "Create and empty #{confdir_path}/vcenter.conf file:"
    on(agent, "rm -rf #{confdir_path}/vcenter.conf")
    puts "list deleted file"
    on(agent, "ls -l #{confdir_path}/vcenter.conf")
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => 1) do |result|
      puts "cat #{confdir_path}/vcenter.conf on agent"
      on(agent, "cat #{confdir_path}/vcenter.conf")
      assert_match(/Error: Could not run: Puppet detected a problem with the information returned from vSphere when accessing vsphere_vm/, result.output, 'Test Failed')
      assert_match(/To use this module you must provide the following settings: host/, result.output, 'Test Failed')
    end
  end
end
