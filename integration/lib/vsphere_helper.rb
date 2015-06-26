require 'rbvmomi'

# Method ensure_vm_is_absent
# The method will delete/absent a machine, either VM or template
#
# ==== Attributes
#
# * +host+ - There host where the delete/absent command is executed
# * +puppet+ - The puppet command
# * +vsphere_vm+ - puppetlabs-vsphere resource type
#
# ==== Returns
#
# +nil+ - This is a 'do something' method, like void method in Java
#
# ==== Examples
# Execute the below command to delete/absent the virtual machine named virtualmachine001
# puppet apply -e "vsphere_vm { 'virtualmachine001': ensure =< 'absent'}"

def ensure_vm_is_absent(host, name)
  on(host, "puppet apply -e \"vsphere_vm { '#{name}': ensure => 'absent'}\"")
end

# Method machine_exists?(datacenter, name, path)
# The method validates if the provided machine(either VM or template)
# is exists in the provided datacenter using rbvmomi, it does not
# rely on vsphere module to verify the machine existing status
#
# ==== Attributes
#
# * +server+ - The link to vCenter server, i.e 'vmware-vc1.ops.puppetlabs.net'
# * +userid+ - The login user for the above server
# * +passwd+ - The login password
# * +datacenter+ - The datacenter that this method is looking for the machine
# * +name+ - The name of the machine being looked for
# * +path+ - The path where the machine might reside. Notice: this function
# finds a datacenter before finding the machine, therefore the path should not be
# an absolute path to the machine, but it start from inside of the datacenter
# i.e: the absolute path to the machine is /opdx/eng/integration/vm
# then the +path+ here should only be /eng/integration/vm
#
# ==== Returns
# +1+ - if the machine cannot be found, test fails immediately
# +0+ - if the machine is found

def machine_exists?(datacenter, name, path)
  server  = ENV['VCENTER_SERVER']
  userid  = ENV['VCENTER_USER']
  passwd  = ENV['VCENTER_PASSWORD']

  vim = RbVmomi::VIM.connect insecure: 'true', host: server, user: userid, password: passwd
  dc = vim.serviceInstance.find_datacenter(datacenter) or fail "datacenter not found"
  vm = dc.find_vm("#{path}/#{name}")
  fail_test "Cannot find the #{type}: #{name}" unless vm
end

# Method vm_exists?(datacenter, name)
# The method validates if the provided VM is existing in the provided datacenter
# using rbvmomi, it does not rely on vsphere module to verify the machine existing status
#
# ==== Attributes
#
# * +datacenter+ - The datacenter that this method is looking for the VM
# * +path+ - The path where the machine might reside. Notice: this function
# finds a datacenter before finding the VM, therefore the path should not be
# an absolute path to the VM, but it start from inside of the datacenter
# i.e: the absolute path to the VM is /opdx/eng/integration/vm
# then the +path+ here should only be /eng/integration/vm
# * +name+ - The name of the VM being looked for
# ==== Returns
# +1+ - if the VM cannot be found, test fails immediately
# +0+ - if the VM is found
def vm_exists?(datacenter, name)
  machine_exists?(datacenter, name, '/eng/integration/vm')
end

# Method template_exists?(datacenter, name)
# The method validates if the provided template is existing in the provided datacenter
# using rbvmomi, it does not rely on vsphere module to verify the machine existing status
#
# ==== Attributes
#
# * +datacenter+ - The datacenter that this method is looking for the template
# * +path+ - The path where the machine might reside. Notice: this function
# finds a datacenter before finding the template, therefore the path should not be
# an absolute path to the template, but it start from inside of the datacenter
# i.e: the absolute path to the template is /opdx/eng/integration/template
# then the +path+ here should only be /eng/integration/template
# * +name+ - The name of the template being looked for
# ==== Returns
# +1+ - if the template cannot be found, test fails immediately
# +0+ - if the template is found
def template_exists?(datacenter, name)
  machine_exists?(datacenter, name, '/eng/integration/template')
end

# Method vm_powerstate?(datacenter, name, desired_state)
# The method validates if the provided VM desired state is matching with the
# real state of the VM in the provided datacenter using rbvmomi, it does not
# rely on vsphere module to verify the machine state
#
# ==== Attributes
#
# * +server+ - The link to vCenter server, i.e 'vmware-vc1.ops.puppetlabs.net'
# * +userid+ - The login user for the above server
# * +passwd+ - The login password
# * +datacenter+ - The datacenter that this method is looking for the machine
# * +path+ - The path where the machine might reside. Notice: this function
# finds a datacenter before finding the machine, therefore the path should not be
# an absolute path to the machine, but it start from inside of the datacenter
# i.e: the absolute path to the machine is /opdx/eng/integration/vm
# then the +path+ here should only be /eng/integration/vm
# * +desired_state+ - The desired state of the VM
# ==== Returns
# +1+ - if the 'desired state' is NOT matching with real state, test fails immediately
# +0+ - if the 'desired state' IS matching with real state
def vm_powerstate?(datacenter, name, desired_state)
  server  = ENV['VCENTER_SERVER']
  userid  = ENV['VCENTER_USER']
  passwd  = ENV['VCENTER_PASSWORD']

  vim   = RbVmomi::VIM.connect insecure: 'true', host: server, user: userid, password: passwd
  dc    = vim.serviceInstance.find_datacenter(datacenter) or fail "datacenter not found"
  vm    = dc.find_vm("/eng/integration/vm/#{name}")
  powerState = vm.runtime.powerState
  fail_test "The current VM power state is '#{powerState}'" unless (powerState == desired_state)
end
