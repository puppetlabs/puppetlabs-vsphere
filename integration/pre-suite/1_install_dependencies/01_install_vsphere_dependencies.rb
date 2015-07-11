test_name "QA-1912 - C64678 - Install vSphere module dependencies"

agents.each do |agent|
  path = agent.file_exist?("#{agent['privatebindir']}/gem") ? agent['privatebindir'] : agent['puppetbindir']

  step 'install rbvmomi and hocon gems'
  on(agent, "#{path}/gem install rbvmomi hocon")
end
