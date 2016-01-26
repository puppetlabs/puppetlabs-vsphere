test_name "FM-46231 - C97275 - Install PE license key on master"

# Set variables for test
license_key = '/etc/puppetlabs/license.key'
license_bak = '/tmp/license.key.bak'

myLicenseFile =<<-EOF
#######################
#  Begin License File #
#######################
# PUPPET ENTERPRISE LICENSE - Puppet Labs
to: 中国 日本भारत Việt العراق
nodes: 90
start: 2016-01-25
end: 2035-06-13
#####################
#  End License File #
#####################
EOF

step 'Create /etc/puppetlabs/license.key file...' do
  create_remote_file(master, '/etc/puppetlabs/license.key', myLicenseFile)
  on(master, "chmod 644 /etc/puppetlabs/license.key")
end

step 'Validate the /etc/puppetlabs/license.key' do
  on(master, puppet('license'), :acceptable_exit_code => [0]) do |result|
    assert_match(/You are currently licensed for/, result.stdout, "'puppet license' test failed!!!")
  end
end
