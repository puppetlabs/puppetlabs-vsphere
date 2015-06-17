# This file is only for local testing
# CI task will have its own VC1 credentials
require 'erb'

step 'Exporting credentials'
server    = ENV['VCENTER_SERVER']
user      = ENV['VCENTER_USER']
password  = ENV['VCENTER_PASSWORD']

# path       = '/etc/puppetlabs/puppet/vcenter.conf'
#
# local_files_root_path     = ENV['FILES'] || 'files'
# vcenter_conf_template     = File.join(local_files_root_path, 'vcenter_conf.erb')
# vcenter_conf_erb          = ERB.new(File.read(vcenter_conf_template)).result(binding)
#
# step 'add env var to hosts'
# agents.each do |agent|
#   create_remote_file(agent, path, vcenter_conf_erb)
# end
step 'add env var to hosts'
agents.each do |agent|
  agent.add_env_var("VCENTER_SERVER", "#{server}")
  agent.add_env_var("VCENTER_USER", "#{user}")
  agent.add_env_var("VCENTER_PASSWORD", "#{password}")
end
