[![Build
Status](https://travis-ci.com/puppetlabs/puppetlabs-vsphere.svg?token=eSG6MMwAUKyfRwi9jMcv&branch=master)](https://travis-ci.org/puppetlabs/puppetlabs-vsphere)

# vsphere

#### Table of Contents

1. [Module Description - What the module does and why it is useful](#module-description)
2. [Setup](#setup)
    * [Requirements](#requirements)
    * [Installing the vsphere module](#installing-the-vsphere-module)
3. [Getting Started with vSphere](#getting-started-with-vsphere)
4. [Usage - Configuration options and additional functionality](#usage)
    * [List and manage vSphere machines](#list-and-manage-vsphere-machines)
    * [Customize vSphere machines](#customize-vsphere-machines)
    * [Create linked clones](#create-linked-clones)
    * [Delete vSphere machines](#delete-vsphere-machines)
    * [Purge unmanaged virtual machines](#purge-unmanaged-virtual-machines)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
    * [Types](#types)
    * [Parameters](#parameters)
6. [Known Issues](#known-issues)
7. [Limitations - OS compatibility, etc.](#limitations)

## Module Description

VMware vSphere is a cloud computing virtualization platform. The vSphere module allows you to manage vSphere machines using Puppet.

## Setup

### Requirements

* Puppet Enterprise 3.7 or greater
* Ruby 1.9 or greater
* Rbvmomi Ruby gem 1.8 or greater
* vSphere 5.5

### Installing the vSphere module

#### On Debian 7 and 8, Ubuntu 14.04 LTS, and similar

1. Install the required dependencies:

  On Debian 7 and 8, Ubuntu 14.04 LTS and similar
  ```
  apt-get install zlib1g-dev libxslt1-dev build-essential
  ```

  On RHEL 6 and 7, CentOS, and similar
  ```
  yum install zlib-devel libxslt-devel patch gcc
  ```

2. Install the required gems with this command:

  ```
  /opt/puppet/bin/gem install rbvmomi --no-ri --no-rdoc
  /opt/puppet/bin/gem install hocon --version='~>1.0.0' --no-ri --no-rdoc
  ```

  If you are running Puppet Enterprise 2015.2.0 you need to use the updated path:

  ```
  /opt/puppetlabs/puppet/bin/gem install rbvmomi --no-ri --no-rdoc
  /opt/puppetlabs/puppet/bin/gem install hocon --version='~>1.0.0' --no-ri --no-rdoc
  ```

**Note:** Example pins the hocon gem version to prevent possible incompatibilities.

#### Configuring credentials

1. Set the following environment variables specific to your vSphere installation:

    * Required Settings:

    ```
    export VCENTER_SERVER='your-host'
    export VCENTER_USER='your-username'
    export VCENTER_PASSWORD='your-password'
    ```

    * Optional Settings:

    ```
    # Whether to ignore SSL certificate errors. Defaults to true.
    export VCENTER_INSECURE='true or false'

    # Whether to use SSL. Defaults to true.
    export VCENTER_SSL='true or false'

    # Sets vSphere server port to connect to. Defaults to 443(SSL) or 80(non-SSL).
    export VCENTER_PORT='your-port'
    ```

    Alternatively, you can provide the information in a configuration
    file. Store this as `vcenter.conf` in the relevant
    [confdir](https://docs.puppetlabs.com/puppet/latest/reference/dirs_confdir.html). This should be:

    * nix Systems: `/etc/puppetlabs/puppet`
    * Windows: `C:\ProgramData\PuppetLabs\puppet\etc`
    * non-root users: `~/.puppetlabs/etc/puppet`

    The file format is:

    ```
    vcenter: {
      host: "your-host"
      user: "your-username"
      password: "your-password"
    }
    ```

    Or with all the settings:

    ```
    vcenter: {
      host: "your-host"
      user: "your-username"
      password: "your-password"
      port: your-port
      insecure: false
      ssl: false
    }
    ```
    **Warning**: Usernames that contain a backslash, typically Active Directory domain accounts, must be triple-quoted. For example:

    ```
    vcenter: {
      host: "your-host"
      user: """DOMAIN\your-username"""
      password: "your-password"
    }
    ```

    Note that you can use either the environment variables or the config file. If both are present the environment variables will be used. You **cannot** have some settings in environment variables and others in the config file.

2. Finally install the module with:

  `puppet module install puppetlabs-vsphere`


## Getting started with vSphere

This module allows for describing a vSphere machine using the Puppet
DSL. To create a new machine from a template or other machine and keep it
powered on:

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure => running,
  source => '/opdx1/vm/eng/source',
}
```

To create the same machine without booting it, or to boot it at a later time,
change the `ensure` parameter to `stopped`:

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure => stopped,
  source => '/opdx1/vm/eng/source',
}
```

To create the same machine on a specific datastore, add the `datastore` parameter:

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure    => stopped,
  source    => '/opdx1/vm/eng/source',
  datastore => 'datastore1',
}
```


## Usage

### List and manage vSphere machines

In addition to creating new machines, as above, this module supports listing and managing machines via `puppet resource`:

`puppet resource vsphere_vm`

Note that this outputs some read-only information about the machine,
for instance:

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure                      => 'present',
  resource_pool               => 'general1',
  cpu_reservation             => '0',
  cpus                        => '1',
  guest_ip                    => '10.32.99.41',
  hostname                    => 'debian',
  instance_uuid               => '501870f2-f891-879f-2bb7-f87023789959',
  memory                      => '1024',
  memory_reservation          => '0',
  number_ethernet_cards       => '1',
  power_state                 => 'poweredOn',
  snapshot_disabled           => false,
  snapshot_locked             => false,
  snapshot_power_off_behavior => 'powerOff',
  template                    => false,
  tools_installer_mounted     => false,
  uuid                        => '4218419b-3b98-18ca-e77f-93b567dda463',
}
```

The read-only properties are documented in the reference section below.

### Customize vSphere machines

You can customize vSphere machines using the Puppet DSL. Note that customizing a running vSphere machine reboots the machine.

To modify an existing machine:

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure       => present,
  memory       => 1024,
  cpus         => 1,
  extra_config => {
    'advanced.setting' => 'value',
  }
}
```

### Create linked clones

You can also specify that a newly launched machine should be a linked clone. Linked clones share a disk with the source machine.

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure       => present,
  source       => '/opdx1/vm/eng/source',
  linked_clone => true,
}
```

### Delete vSphere machines

You can also delete the machine we created above by setting the `ensure`
property to `absent` in the manifest or using `puppet resouce` like so:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=absent

To remove only the machine's definition, but leave the underlying configuration
and disk files in place, you can set `ensure` to `unregistered`:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=unregistered

Please note that the module currently provides no mechanism to clean up the files left behind by this operation.

### Purge unmanaged virtual machines

If you are using Puppet as the only tool to manage the machines in your
vSphere installation, you can have Puppet automatically delete any
machines not specified in your manifest. This can be useful if you want
to enforce only one way of doing things.

Doing this uses the `resources`
[type](https://docs.puppetlabs.com/references/latest/type.html#resources)
and the associated `purge` parameter. This is described in the
documentation as follows:

> Whether to purge unmanaged resources. When set to true, this deletes
  any resource that is not specified in your configuration and is not
  autorequired by any managed resources.

The example below shows this in use. Remember that this *deletes all your virtual
machines* except those described in the same manifest. **Do not run
the following code on its own.**

```puppet
resources { 'vsphere_vm':
  purge => true,
}
```

A safer option is to run this with the `noop` parameter set to true.
This won't actually delete the unmanaged machines, but it will tell you
about machines it would have deleted. This means you can add them to
your manifest or delete them manually as needed.

```puppet
resources { 'vsphere_vm':
  purge => true,
  noop  => true,
}
```

This outputs something similar in the logs (this example running
under debug):

```
Debug: Prefetching rbvmomi resources for vsphere_vm
Notice: /Stage[main]/Main/Vsphere_vm[/west1/vm/test]/ensure: current_value running, should be absent (noop)
Debug: Finishing transaction 70211596554260
Debug: Storing state
Debug: Stored state in 0.43 seconds
```

### A note on datacenters

By default, this module uses the default datacenter for your installation. If this fails or if you have multiple virtual datacenters on vSphere, you can specify which datacenter you are managing using the `VCENTER_DATACENTER` environment variable like so:

`export VCENTER_DATACENTER=my-datacenter`

This can also be set in the config file as `datacenter`.

If the datacenter is nested within folders (groups) in vSphere, specify the full path to the datacenter, for example:

`export VCENTER_DATACENTER=Australia/Perth/DC1`

## Reference

### Types

* `vsphere_vm`: Manages a vSphere virtual machine.

### Parameters

#### Type: vsphere_vm

##### `ensure`
Specifies the basic state of the resource. Valid values are 'present', 'running',
stopped', and 'absent'. If the machine is a template, then only 'present' and 'absent' are valid states. Defaults to 'present'.

Values have the following effects:

* 'present', 'running': Ensures that the VM is up and running. If the VM doesn't yet exist, a new one is created as specified by the other properties.
* 'stopped': Ensures that the VM is created, but is not running. This can be used to shut down running VMs, as well as for creating VMs without having them boot immediately.
* 'absent': Ensures that the VM and all of its files are removed.

##### `name`
*Required* The full path for the machine, including the datacenter identifier.

##### `resource_pool`
The name of the resource_pool in which to launch the machine. If you have nested resource pools, you can specify them using a slash-separated value. For example, with a cluster named "general1" that contains a resource pool called "QA", specify `/general1/QA` to put a VM into this resource pool. Defaults to the first cluster in the datacenter.

For compatibility with version 1.1.0 and earlier, you can also specify just the name of a host cluster without any slashes. This usage generates a warning and is removed at a later time.

When using clusters nested under a folder, specify the whole path to the resource pool. For example, to use a resource pool named `QA` in a cluster named "general1" that is in a folder named "Folder1", specify `/Folder1/general1/QA`. The module will attempt to search down the tree for the resource pool, but explicitly specifying the path will ensure compatibility.

##### `source`
The path within the specified datacenter to the virtual machine or
template to base the new virtual machine on. Specifying a source
is required when specifying `ensure => 'present'`.

##### `source_type`
The source type of the new virtual machine. Valid options are 'vm' if the source
is another virtual machine, 'template' if the source is a template, or 'folder'
if the source is an imported/uploaded virtual machine folder on the datastore.
Defaults to 'vm'.

##### `datastore`
The datastore name within the specified `resource_pool` where the virtual machine
will reside. This option is only available when creating a virtual machine from
a `source` and is required when specifying a different `resource_pool`.
This defaults to the first datastore in the `resource_pool`.

##### `template`
Whether or not the machine is a template. Defaults to false.

##### `memory`
The amount of memory to allocate to the new machine. Defaults to the same as the template or source machine.

##### `cpus`
The number of CPUs to allocate to the new machine. Defaults to the same as the template or source machine.

##### `delete_from_disk`
Whether or not to delete the files from disk. Valid options are true or false.
Providing a value of true results in the VM and all of the related files being
deleted from the datastore. Providing false removes the VM from the inventory,
but retain the VM files on the datastore. Defaults to true.

##### `annotation`
User provided description of the machine.

##### `extra_config`
A hash containing [vSphere extraConfig](https://www.vmware.com/support/developer/converter-sdk/conv55_apireference/vim.vm.ConfigInfo.html) settings for the virtual machine. Defaults to undef.

##### `create_command`
A hash containing details of a command to be run on the newly launched guest when it is first created. Note that this requires the guest to have a system user with a known password and for the machine to have VMware tools preinstalled.

```
create_command => {
  command => '/bin/ps',
  arguments => 'aux',
  working_directory => '/',
  user => 'root',
  password => 'password',
}
```

Both `working_directory` (defaults to `/`) and `arguments` (defaults to
`nil`) are optional.

##### `customization_spec`
The name of an existing customization spec in vCenter which is applied
to the VM when it is cloned.

##### `cpu_reservation`
*Read Only*. How many of the CPUs allocated are reserved just for this
machine.

##### `memory_reservation`
*Read Only*. How much of the memory allocated is reserved just for this
machine.

##### `cpu_affinity`
*Read Only*. A list of processors which can be used by the VM. Presented
as an array of the numeric identifiers.

##### `memory_affinity`
*Read Only*. A list of NUMA nodes which can be used by the VM. Presented
as an array of the numeric identifiers.

##### `number_ethernet_cards`
*Read Only* The number of virtual ethernet cards available to the
machine.

##### `power_state`
*Read Only*. Whether the machine is on or off.

##### `tools_installer_mounted`
*Read Only*. Whether or nor the VMware tools installer is mounted.

##### `snapshot_disabled`
*Read Only*. Snapshots are disabled for this machine.

##### `snapshot_locked`
*Read Only*. Snapshots for this machine are currently locked.

##### `snapshot_power_off_behaviour`
*Read Only*. Whether to revert to a snapshot when the machine is powered
off.

##### `uuid`
*Read Only*. The BIOS unique identifier.

##### `instance_uuid`
*Read Only*. Unique identifier for the vSphere instance.

##### `hostname`
*Read Only*. The hostname of the machine if one is assigned.

##### `guest_ip`
*Read Only*. The IP address assigned to the machine.

##### `datacenter`
*Read Only*. The datacenter this machine is running on.

##### `vcenter_full_version`
*Read Only*. The full version of the vCenter managing this machine.

##### `vcenter_name`
*Read Only*. The name of the vCenter managing this machine.

##### `vcenter_uuid`
*Read Only*. The UUID of the vCenter managing this machine.

##### `vcenter_version`
*Read Only*. The product version of the vCenter managing this machine.

##### `drs_behavior`
*Read Only*. Distributed Resource Scheduler behaviour, should be one of:

* fullyAutomated - Specifies that VirtualCenter should auxtomate both the
migration of virtual machines and their placement with a host at power
on.
* manual -Specifies that VirtualCenter should generate recommendations for
virtual machine migration and for placement with a host, but should not
implement the recommendations automatically.
* partiallyAutomated - Specifies that VirtualCenterter should generate
recommendations for virtual machine migration and for placement with a
host, but should automatically implement only the placement at power on.


## Limitations

For an extensive list of supported operating systems, see [metadata.json](https://github.com/puppetlabs/puppetlabs-vsphere/blob/master/metadata.json)

The vSphere module is only available for Puppet Enterprise 3.7 and later. This module has been tested with vSphere 5.5.

## Known Issues

When using the vSphere module with the Puppet Server, you first need to
ensure the module is successfully loaded. Run the Puppet agent on the master node, for instance, with `puppet agent
-t`. If you do not do this, the first, and only the first, run of
the `vsphere_vm` resource fails on the agent with the following error:

```
Error: Could not retrieve catalog from remote server: Error 400 on
SERVER: Could not autoload puppet/type/vsphere_vm: Could not autoload
puppet/provider/vsphere_vm/rbvmomi: no such file to load --
puppet_x/puppetlabs/prefetch_error on node
```

## Development

This module was built by Puppet Labs specifically for use with Puppet Enterprise (PE).

If you run into an issue with this module, or if you would like to request a feature, please [file a ticket](https://tickets.puppetlabs.com/browse/MODULES/).

If you have problems getting this module up and running, please [contact Support](http://puppetlabs.com/services/customer-support).
