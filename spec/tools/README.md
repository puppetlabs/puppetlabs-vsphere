# Tools
## vSphere VM Cleanup
A script to clean up any orphaned VMs that were created but not cleaned up on the vCenter server we use for testing. It
was observed that VMs were piling up on the vCenter server due to timeouts or transient network errors causing the 
clean-up hooks not to execute.


## Usage
First, export the environment variables to allow the script to authenticate to the vCenter server. Ask the IAC Team if
you need to locate these details - we have a specific account with perms to create / destroy VMs in the specific
allocated area on the server.
```shell script
export VCENTER_SERVER=vcenter-server.example.com
export VCENTER_USER=username
export VCENTER_PASSWORD=password
```
At the project root dir:
```shell script
bundle install --path .bundle
bundle exec ruby spec/tools/vsphere_vm_cleanup.rb
```
The script will:
- Connect to the vCenter server defined in `$VCENTER_SERVER`
- Locate any VMs under the folder `vsphere-module-testing/eng/tests/`
- Generate a list of candidates to delete based on the VM name (any VMs created by Spec tests in this module should
have a name that matches: `MODULES-\w{16}(?:-(?:source|remote))?`)
- List the VMs it has selected to delete
- Prompt the user if they want to continue (enter `Y` to do so)
- Give the user one last chance to abort (3 seconds)
- DESTROYS THE VMS!