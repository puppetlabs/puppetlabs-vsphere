# This file is only for local testing
# CI task will have its own credentials
require 'erb'

confine :except, :roles => %w{master dashboard database}

step 'Exporting credentials'
server    = ENV['VCENTER_SERVER']
user      = ENV['VCENTER_USER']
password  = ENV['VCENTER_PASSWORD']

step 'Add env var to hosts'
agents.each do |agent|
  agent.add_env_var("VCENTER_SERVER", "#{server}")
  agent.add_env_var("VCENTER_USER", "#{user}")
  agent.add_env_var("VCENTER_PASSWORD", "#{password}")
end
