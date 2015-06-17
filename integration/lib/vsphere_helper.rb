require 'rbvmomi'

# ensure to absent a puppetlabs_machine
def ensure_absent(host, path, name)
  on(host, "puppet apply -e \"vsphere_vm { '#{path}/#{name}': ensure => 'absent'}\"")
end

# Verify VM/template has been successfully created in vCenter
def is_created?(datacenter, name, type)
  server  = ENV['VCENTER_SERVER']
  userid  = ENV['VCENTER_USER']
  passwd  = ENV['VCENTER_PASSWORD']

  type == "VM" ? (path = '/eng/integration/vm') : (path = '/eng/integration/template')

  vim = RbVmomi::VIM.connect insecure: 'true', host: server, user: userid, password: passwd
  dc = vim.serviceInstance.find_datacenter(datacenter) or fail "datacenter not found"
  vm = dc.find_vm("#{path}/#{name}")
  fail_test "Cannot find the #{type}: #{name}" unless vm
end
