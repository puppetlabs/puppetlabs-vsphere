test_name "QA-1912 - C64678 - Install vSphere module dependencies"

agents.each do |agent|
  path = if agent.file_exist?("#{agent['privatebindir']}/gem")
           agent['privatebindir']
         elsif agent.file_exist?("#{agent['puppetbindir']}/gem")
           agent['puppetbindir']
         else
           # Passing type: aio in the beaker configs (as used by Jenkins) forces privatebindir
           # and puppetbindir values to look in /opt/puppetlabs, whatever version of Puppet
           # you're actually using. For instance for PE 3.8.3, which uses Puppet 3.8.4, this
           # is the wrong path. So we simply set it to the most likely location.
           '/opt/puppet/bin'
         end

  step 'install rbvmomi and hocon gems'
  on(agent, "#{path}/gem install rbvmomi hocon")
end
