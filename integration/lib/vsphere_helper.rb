require 'rbvmomi'

def ensure_vm_is_absent(host, name)
  on(host, "puppet apply -e \"vsphere_vm { '#{name}': ensure => 'absent'}\"")
end

def machine_exists?(datacenter, name, path)
  server  = ENV['VCENTER_SERVER']
  userid  = ENV['VCENTER_USER']
  passwd  = ENV['VCENTER_PASSWORD']

  vim = RbVmomi::VIM.connect insecure: 'true', host: server, user: userid, password: passwd
  dc = vim.serviceInstance.find_datacenter(datacenter) or fail "datacenter not found"
  vm = dc.find_vm("#{path}/#{name}")
  fail_test "Cannot find the #{type}: #{name}" unless vm
end

def vm_exists?(datacenter, name)
  machine_exists?(datacenter, name, '/eng/integration/vm')
end

def template_exists?(datacenter, name)
  machine_exists?(datacenter, name, '/eng/integration/template')
end
