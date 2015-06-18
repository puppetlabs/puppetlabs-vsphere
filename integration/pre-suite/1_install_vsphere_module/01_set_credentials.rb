# This file is only for local testing
# CI task will have its own credentials
require 'erb'

confine :except, :roles => %w{master dashboard database}

step 'Exporting credentials'
server    = ENV['VCENTER_SERVER']
user      = ENV['VCENTER_USER']
password  = ENV['VCENTER_PASSWORD']

local_files_root_path     = ENV['FILES'] || 'files'
vcenter_conf_template     = File.join(local_files_root_path, 'vcenter_conf.erb')
vcenter_conf_erb          = ERB.new(File.read(vcenter_conf_template)).result(binding)

step 'Create vcenter.conf file on the agent node'
agents.each do |agent|
  confdir_path = on(agent, puppet('config', 'print', 'confdir')).stdout.rstrip
  create_remote_file(agent, "#{confdir_path}/vcenter.conf", vcenter_conf_erb)
end
