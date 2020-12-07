# frozen_string_literal: true

require 'rbvmomi'

credentials = {
  host: ENV['VCENTER_SERVER'],
  user: ENV['VCENTER_USER'],
  password: ENV['VCENTER_PASSWORD'],
  insecure: true,
}
datacenter = ENV['VCENTER_DATACENTER']
vim = RbVmomi::VIM.connect credentials
datacenter = vim.serviceInstance.find_datacenter(datacenter)

TEST_VM_LOC = 'vsphere-module-testing/eng/tests/'

puts "Connecting to vCenter server: #{ENV['VCENTER_SERVER']}"

puts 'Connecting to datacenter on vCenter'
folder = datacenter.find_folder(TEST_VM_LOC)
vms = folder.children.select { |obj| obj.instance_of? RbVmomi::VIM::VirtualMachine }
vm_count = vms.count.to_i

if vm_count == 0
  puts 'No VMs detected, exiting!'
  exit(0)
end

puts "Found #{vm_count} VMs under #{TEST_VM_LOC} that conform to naming convention of module test VMs:"

vms_to_delete = vms.select { |vm| vm.name.match(%r{MODULES-\w{16}(?:-(?:source|remote))?}) }
vms_to_delete.each do |vm|
  puts "- #{vm.name}"
end

print "\nWould you like to delete these VMs? [Y/N]: "
confirm = gets.chomp

exit(0) unless confirm.casecmp('y') == 0

3.downto(1) do |i|
  print "\rDeleting VMs in #{i}"
  sleep 1
end

puts ''

vms_to_delete.each do |vm|
  puts "Destroying #{vm.name}"
  vm.PowerOffVM_Task.wait_for_completion if vm.runtime.powerState == 'poweredOn'
  vm.Destroy_Task.wait_for_completion
end
