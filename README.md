[![Build
Status](https://magnum.travis-ci.com/puppetlabs/puppetlabs-vsphere.svg?token=RqtxRv25TsPVz69Qso5L)](https://magnum.travis-ci.com/puppetlabs/puppetlabs-vsphere)

####Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#module-description)
3. [Setup](#setup)
  * [Requirements](#requirements)
  * [Installing the vsphere module](#installing-the-vsphere-module)
4. [Getting Started with vSphere](#getting-started-with-vsphere)
5. [Usage - Configuration options and additional functionality](#usage)
6. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
  * [Types](#types)
  * [Parameters](#parameters)
7. [Limitations - OS compatibility, etc.](#limitations)

## Overview

Managing vSphere machines using the Puppet DSL.

## Description

## Setup

### Requirements

* Puppet Enterprise 3.7 or greater
* Ruby 1.9 or greater
* RBVMOMI Ruby gem

### Installing the vSphere module

1. First install the required dependencies. Install the gem with this command:

  `/opt/puppet/bin/gem install rbvmomi hocon`

  This allows the gem to be used by the Puppet Enterprise Ruby.

  * If you're running [Puppet Server](https://github.com/puppetlabs/puppet-server), you need to make the gem available to JRuby with:

    `/opt/puppet/bin/puppetserver gem install rbvmomi hocon`

    Once the gem is installed, restart Puppet Server.

2. Set the following environment variables specific to your vSphere
   installation:

  * Required Settings:
      
      ~~~
      export VCENTER_SERVER='your-host'
      export VCENTER_USER='your-username'
      export VCENTER_PASSWORD='your-password'
      ~~~

  * Optional Settings:
      
      ~~~
      # Whether to ignore SSL certificate errors. Defaults to true.
      export VCENTER_INSECURE='true or false'

      # Whether to use SSL. Defaults to true.
      export VCENTER_SSL='true or false'

      # Sets vSphere server port to connect to. Defaults to 443(SSL) or 80(non-SSL).
      export VCENTER_PORT='your-port'
      ~~~

   Alternatively, you can provide the information in a configuration
file. Store this as `vcenter.conf` in the relevant
[confdir](https://docs.puppetlabs.com/puppet/latest/reference/dirs_confdir.html). This should be:

   * nix Systems: `/etc/puppetlabs/puppet`
   * Windows: `C:\ProgramData\PuppetLabs\puppet\etc`
   * non-root users: `~/.puppetlabs/etc/puppet`

   The file format is:

      ~~~
      vcenter: {
        host: 'your-host'
        user: 'your-username'
        password: 'your-password'
      }
      ~~~

   Or with all the settings:

      ~~~
      vcenter: {
        host: 'your-host'
        user: 'your-username'
        password: 'your-password'
        port: your-port
        insecure: false
        ssl: false
      }
      ~~~

    Note that you can use either the environment variables or the config file. If both are present the environment variables will be used. You **cannot** have some settings in environment variables and others in the config file.

3. Finally install the module with:

  `puppet module install puppetlabs-vsphere`


## Getting started with vSphere

This module allows for describing a vSphere machine using the Puppet
DSL. To create a new machine from a template or other machine and keep it
powered on:

~~~
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure => running,
  source => '/opdx1/vm/eng/source',
  memory => 1024,
  cpus   => 1,
}
~~~

To create the same machine without booting it, or to boot it at a later time,
change the `ensure` parameter to `stopped`:

~~~
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure => stopped,
  source => '/opdx1/vm/eng/source',
  memory => 1024,
  cpus   => 1,
}
~~~

## Usage

###List and manage vSphere machines

In addition to creating new machines, as above, this module supports listing and managing machines via `puppet resource`:

`puppet resource vsphere_vm`

Note that this will output some read-only information about the machine,
for instance:

~~~
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
  snapshot_disabled           => 'false',
  snapshot_locked             => 'false',
  snapshot_power_off_behavior => 'powerOff',
  template                    => 'false',
  tools_installer_mounted     => 'false',
  uuid                        => '4218419b-3b98-18ca-e77f-93b567dda463',
}
~~~

The read-only properties are documented in the reference section below.

###Customize vSphere machines

You can customize vSphere machines using the Puppet DSL. Note that customizing a running vSphere machine will perform a reboot of the machine.

To modify an existing machine:

~~~
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure       => present,
  memory       => 1024,
  cpus         => 1,
  extra_config => {
    'advanced.setting' => 'value',
  }
}
~~~

###Create linked clones

You can also specify that a newly launched machine should be a linked clone. Linked clones share a disk with the source machine.

~~~
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure       => present,
  source       => '/opdx1/vm/eng/source',
  linked_clone => true,
}
~~~

###Delete vSphere machines

You can also delete the machine we created above by setting the `ensure`
property to `absent` in the manifest or using `puppet resouce` like so:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=absent

To remove only the machine's definition, but leave the underlying configuration
and disk files in place, you can set `ensure` to `unregistered`:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=unregistered

Please note that the module currently provides no mechanism to clean up the
files left behind by this operation.

### A note on datacenters

By default, this module uses the default datacenter for your installation. If
this fails or if you have multiple virtual datacenters on vSphere, you
can specify which datacenter you are managing using the
`VCENTER_DATACENTER` environment variable like so:

`VCENTER_DATACENTER=my-datacenter puppet resource vpshere_vm`

This can also be set in the config file as `datacenter`.

##Reference

###Types

* `vsphere_vm`: Manages a vSphere virtual machine.

###Parameters

####Type: vsphere_vm

#####`ensure`
Specifies the basic state of the resource. Valid values are 'present', 'running',
stopped', and 'absent'. If the machine is a template, then only 'present' and 'absent' are valid states. Defaults to 'present'.

Values have the following effects:

* 'present', 'running': Ensures that the VM is up and running. If the VM doesn't yet exist, a new one is created as specified by the other properties.
* 'stopped': Ensures that the VM is created, but is not running. This can be used to shut down running VMs, as well as for creating VMs without having them boot immediately.
* 'absent': Ensures that the VM and all of its files are removed.

#####`name`
*Required* The full path for the machine, including the datacenter identifier.

#####`resource_pool`
The name of the resource_pool in which to launch the machine. Defaults to the default resource pool for the datacenter.

#####`source`
The path within the specified datacenter to the virtual machine or
template to base the new virtual machine on. Specifying a source
is required when specifying `ensure => 'present'`.

#####`source_type`
The source type of the new virtual machine. Valid options are 'vm' if the source
is another virtual machine, 'template' if the source is a template, or 'folder'
if the source is an imported/uploaded virtual machine folder on the datastore.
Defaults to 'vm'.

#####`template`
Whether or not the machine is a template. Defaults to false.

#####`memory`
The amount of memory to allocate to the new machine. Defaults to the same as the template or source machine.

#####`cpus`
The number of CPUs to allocate to the new machine. Defaults to the same as the template or source machine.

#####`delete_from_disk`
Whether or not to delete the files from disk. Valid options are 'true' or 'false'.
Providing a value of 'true' will result in the VM and all of the related files being
deleted from the datastore. Providing 'false' will remove the VM from the inventory,
but retain the VM files on the datastore. Defaults to 'true'.

#####`annotation`
User provided description of the machine.

#####`extra_config`
A hash containing [vSphere extraConfig](https://www.vmware.com/support/developer/converter-sdk/conv55_apireference/vim.vm.ConfigInfo.html) settings for the virtual machine. Defaults to undef.

#####`create_command`
A hash containing details of a command to be run on the newly launched guest when it is first created. Note that this requires the guest to have a system user with a known password and for the machine to have VMware tools preinstalled.

~~~
create_command => {
  command => '/bin/ps',
  arguments => 'aux',
  working_directory => '/',
  user => 'root',
  password => 'password',
}
~~~

Both `working_directory` (defaults to `/`) and `arguments` (defaults to
`nil`) are optional.

#####`cpu_reservation`
*Read Only*. How many of the CPUs allocated are reserved just for this
machine.

#####`memory_reservation`
*Read Only*. How much of the memory allocated is reserved just for this
machine.

#####`number_ethernet_cards`
*Read Only* The number of virtual ethernet cards available to the
machine.

#####`power_state`
*Read Only*. Whether the machine is on or off.

#####`tools_installer_mounted`
*Read Only*. Whether or nor the VMware tools installer is mounted.

#####`snapshot_disabled`
*Read Only*. Snapshots are disabled for this machine.

#####`snapshot_locked`
*Read Only*. Snapshots for this machine are currently locked.

#####`snapshot_power_off_behaviour`
*Read Only*. Whether to revert to a snapshot when the machine is powered
off.

#####`uuid`
*Read Only*. the BIOS unique identifier

#####`instance_uuid`
*Read Only*. unique identifier for the vSphere instance

#####`hostname`
*Read Only*. the hostname of the machine is one is assigned

#####`guest_ip`
*Read Only*. the IP address assigned to the machine

##Limitations

This module is available only for Puppet Enterprise 3.7 and later.

## Development

This module was built by Puppet Labs specifically for use with Puppet Enterprise (PE).

If you run into an issue with this module, or if you would like to request a feature, please [file a ticket](https://tickets.puppetlabs.com/browse/MODULES/).

If you have problems getting this module up and running, please [contact Support](http://puppetlabs.com/services/customer-support).

