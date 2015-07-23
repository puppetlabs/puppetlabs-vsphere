require 'vsphere_helper'
require 'securerandom'
require 'master_manipulator'

test_name 'CLOUD-373 - C68539 - List vSphere machine in wrong DataCenter'

datacenter   = "opdx1"
folder       = '/opdx1/vm/eng/integration/vm'
name         = SecureRandom.hex(8)

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

teardown do
  confine_block :except, :roles => %w{master dashboard database} do
    ensure_vm_is_absent(agent, "#{folder}/#{name}")
  end
end

step "Manipulate the site.pp file on the master node"
site_pp = create_site_pp(master, :manifest => render_manifest(binding))
inject_site_pp(master, prod_env_site_pp_path, site_pp)

confine_block :except, :roles => %w{master dashboard database} do
  step "Creating VM from a template with name: '#{name}'"
  on(agent, puppet('agent', '-t', '--environment production'), :acceptable_exit_codes => [0,2]) do |result|
    assert_match(/#{name}\]\/ensure: changed absent to running/, result.output, 'Failed to create VM from template')
  end

  step "puppet source vsphere_vm: #{folder}/#{name} with correct VCENTER_DATACENTER  "
  on(agent, puppet('resource', 'vsphere_vm', "#{folder}/#{name}")) do |result|
    assert_match(/cpu.*#{cpus}/, result.output, 'Failed to create specified CPU')
    assert_match(/memory.*#{memory}/, result.output, 'Failed to create specified memory')
  end

  step "puppet source vsphere_vm: #{folder}/#{name} with wrong VCENTER_DATACENTER  "
  on(agent, puppet('resource', 'vsphere_vm', "non-exist-datacenter/vm/eng/integration/vm/#{name}")) do |result|
    assert_match(/ensure.*absent/, result.output, 'Failed to look for machine info with wrong datacenter')
    assert_no_match(/Error/, result.output, 'Failed to look for machine info with wrong datacenter')
  end
end
