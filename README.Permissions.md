
# List of required permissions by user story

This list is according to the vSphere 5.5 documentation as provided with the product.

  * CLOUD-281 Create vSphere template from VM: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-FE6DE4DF-FAD0-4BB0-A1FD-AFE9A40F4BFE_copy.html
    - Virtual machine.Provisioning.Create template from virtual machine on the source virtual machine.
    - Virtual machine .Inventory.Create from existing on virtual machine folder where the template is created.
    - Resource.Assign virtual machine to resource pool on the destination host, cluster, or resource pool.
    - Datastore.Allocate space on all datastores where the template is created.
  
  * CLOUD-282 Create vSphere VM from template: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-8254CD05-CC06-491D-BA56-A773A32A8130.html
    - Virtual machine .Inventory.Create from existing on the datacenter or virtual machine folder.
    - Virtual machine.Configuration.Add new disk on the datacenter or virtual machine folder. Required only if you customize the original hardware by adding a new virtual disk.
    - Virtual machine.Provisioning.Deploy template on the source template.
    - Resource.Assign virtual machine to resource pool on the destination host, cluster, or resource pool.
    - Datastore.Allocate space on the destination datastore.
    - Network.Assign network on the network to which the virtual machine will be assigned. Required only if you customize the original hardware by adding a new network card.
    - Virtual machine.Provisioning.Customize on the template or template folder if you are customizing the guest operating system.
    - Virtual machine.Provisioning.Read customization specifications on the root vCenter Server if you are customizing the guest operating system.

  * CLOUD-283 Customise VM in vSphere: Depending on the specific tasks, this
    requires permissions from the Virtual machine.Configuration and Virtual
    machine.Interaction groups. Operations touching on other parts of vSphere
    (Datastore, Network, Resource) may also play a role. vSphere documentation
    has this info distributed across UI descriptions of all possible tasks.

  * CLOUD-284 Delete vSphere VM, CLOUD-285 Delete vSphere template: Permissions not specified in Documentation
    - VMs: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-376174FE-F936-4BE4-B8C2-48EED42F110B.html
    - Templates: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-62F6E880-2D8C-4108-8993-E82DD9AF9E83.html
    - I expect similar permission requirements as the Create cases, but with Delete/Remove instead

  * CLOUD-286 List vSphere machines: For listing VMs any access to the vSphere seems to be enough.

  * CLOUD-288 Purge unmanaged vSphere VMs: a combination of List and Delete, see above

  * CLOUD-287 List vSphere templates, CLOUD-289 Purge unmanaged vSphere templates: a combination of List and Delete, see above

  * CLOUD-290 Pass script to run on boot for vSphere machine: Unclear what/how this is supposed to work

  * CLOUD-291 Create vSphere machine from existing machine: http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-FE6DE4DF-FAD0-4BB0-A1FD-AFE9A40F4BFE_copy.html
    - Virtual machine.Provisioning.Create template from virtual machine on the source virtual machine.
    - Virtual machine.Inventory.Create from existing on virtual machine folder where the template is created.
    - Resource.Assign virtual machine to resource pool on the destination host, cluster, or resource pool.
    - Datastore.Allocate space on all datastores where the template is created.

  * CLOUD-292 Import vSphere template: Documentation specifies no required permissions
    - http://pubs.vmware.com/vsphere-55/index.jsp#com.vmware.vsphere.vm_admin.doc/GUID-17BEDA21-43F6-41F4-8FB2-E01D275FE9B4.html
    - I would expect this to require similar permissions as CLOUD-291 Create vSphere machine from existing machine though.

  * CLOUD-293 Import vSphere machine: Unclear how this is supposed to work, as OVF import seems to always create templates.

