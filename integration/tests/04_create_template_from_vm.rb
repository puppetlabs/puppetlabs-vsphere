require 'vsphere_helper'
require 'securerandom'
require 'erb'
require 'rbvmomi'
require 'master_manipulator'

test_name 'CLOUD-281 - C64686 Create vSphere template from a VM'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration'
name         = SecureRandom.hex(8)
path         = "#{folder}/vm/#{name}"
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
      ensure_vm_is_absent(agent, "#{folder}/vm/#{name}")
      ensure_vm_is_absent(agent, "#{folder}/template/template_from_vm_#{name}")
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

step "Manipulate the site.pp file on the master node the second time"
# Modify manifest_erb file
path              = "#{folder}/template/template_from_vm_#{name}"
status            = 'present'
source_path       = "#{folder}/vm/#{name}"
is_template       = 'true'
manifest_template = File.join(local_files_root_path, 'manifest.erb')
manifest_erb      = ERB.new(File.read(manifest_template)).result(binding)

site_pp = create_site_pp(master, :manifest => manifest_erb)
inject_site_pp(master, prod_env_site_pp_path, site_pp)

step "Creating template from VM"
confine_block :except, :roles => %w{master dashboard database} do
  agents.each do |agent|
    on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/template_from_vm_#{name}\]\/ensure: changed absent to present/, result.output, 'Failed to create template from VM')
    end
  end
end

step "Verify the template has been successfully created in vCenter:"
template_exists?(datacenter, "template_from_vm_#{name}")
