test_name "Install nokogiri dependencies for Debian/Ubuntu"
confine :to, :platform => ['ubuntu-14.04-amd64', 'debian-7-amd64']

agents.each do |agent|
  on(agent, 'apt-get install zlib1g-dev')
end
