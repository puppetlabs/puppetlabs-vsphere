[![Build
Status](https://magnum.travis-ci.com/puppetlabs/puppetlabs-vsphere.svg?token=RqtxRv25TsPVz69Qso5L)](https://magnum.travis-ci.com/puppetlabs/puppetlabs-vsphere)

####Table of Contents

1. [Overview](#overview)
2. [Description - What the module does and why it is useful](#module-description)
3. [Setup](#setup)
  * [Requirements](#requirements)
  * [Installing the vsphere module](#installing-the-vphere-module)
4. [Getting Started with vpshere](#getting-started-with-vsphere)
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

* Puppet 3.4 or greater
* Ruby 1.9 or greater
* RBVMOMI Ruby gem

### Installing the vpshere module

1. First install the required dependencies

  * If you're using open source Puppet, the library gem should be installed
     into the same Ruby used by Puppet. Install the gem with:

      `gem install rbvmomi`

  * If you're running Puppet Enterprise, install the gem with this command:

      `/opt/puppet/bin/gem install rbvmomi`

    This allows the gem to be used by the Puppet Enterprise Ruby.

  * If you're running [Puppet Server](https://github.com/puppetlabs/puppet-server), you need to make the gem available to JRuby with:

      `/opt/puppet/bin/puppetserver gem install rbvmomi`

    Once the gems are installed, restart Puppet Server.

2. Set the following environment variables specific to your vpshere
   installation:

      ~~~
      export VSPHERE_SERVER='your-host'
      export VSPHERE_USER='your-username'
      export VSPHERE_PASSWORD='your-password'
      ~~~

3. Finally install the module with:

     `puppet module install puppetlabs-vsphere`


## Getting started with vpshere

This module allows for describing a vSphere machine using the Puppet
DSL:

*To create a new VM from a Template:*
~~~
vsphere_machine { '/opdx1/vm/eng/sample':
  ensure   => present,
  template => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  compute  => 'general1',
  memory   => 1024,
  cpus     => 1,
}
~~~

*To create a new VM from an existing VM:*
~~~
vsphere_machine { '/opdx1/vm/eng/sample':
  ensure   => present,
  source_vm => '/eng/vms/source',
  compute  => 'general1',
}
~~~

The module also supports listing and managing machines via `puppet resource`:

    puppet resource vsphere_machine

Note that this will output some read-only information about the machine,
for instance:

~~~
vsphere_machine { '/opdx1/vm/eng/sample':
  ensure                      => 'present',
  compute                     => 'general1',
  cpu_reservation             => '0',
  cpus                        => '1',
  memory                      => '1024',
  memory_reservation          => '0',
  number_ethernet_cards       => '1',
  power_state                 => 'poweredOn',
  snapshot_disabled           => 'false',
  snapshot_locked             => 'false',
  snapshot_power_off_behavior => 'powerOff',
  tools_installer_mounted     => 'false',
}
~~~

The read-only properties are documented in the reference section below.

You can also delete the machine we created above by setting the `ensure`
property to `absent` in the manifest or using `puppet resouce` like so:

    puppet resource vsphere_machine /opdx1/vm/eng/garethr-test ensure=absent

### A note on datacenters

By default we will use the default datacenter for your installation. If
this fails or if you have multiple virtual datacenters on vSphere you
can specify which datacenter you are managing using the
`VSPHERE_DATACENTER` environment variable like so:

    VSPHERE_DATACENTER=my-datacenter puppet resource vpshere_machine


## Usage

## References

### Types

* `vsphere_machine`: Manages a vSphere virtual machine.

### Parameters

#### Type: vpshere_machine

#####`ensure`
Specifies the basic state of the resource. Valid values are 'present' and 'absent'.

#####`name`
*Required* The full path for the machine, including the datacenter
identifier.

#####`compute`
*Required* The name of the computre resource in which to launch the
machine.

#####`template`
The path within the specified datacenter to the template to
base the new virtual machine on. Specifying a template or a source_vm is required
when specifying `ensure => 'present'`.

#####`source_vm`
The path within the specified datacenter to the virtual machine to
base the new virtual machine on. Specifying a template or a source_vm is required
when specifying `ensure => 'present'`.

#####`memory`
The amount of memory to allocate to the new machine. Defaults to the
same as the template.

#####`cpus`
The number of CPUs to allocate to the new machine. Defaults to the
same as the template.

#####`cpu_reservation`
*Read Only* How many of the CPUs allocated are reserved just for this
machine.

#####`memory_reservation`
*Read Only* How much of the memory allocated is reserved just for this
machine.

#####`number_ethernet_cards`
*Read Only* The number of virtual ethernet cards available to the
machine.

#####`power_state`
*Read Only* Whether the machine is on or off.

#####`tools_installer_mounted`
*Read Only* Whether or nor the VMware tools installer is mounted.

#####`snapshot_disabled`
*Read Only* Snapshots are disabled for this machine.

#####`snapshot_locked`
*Read Only* Snapshots for this machine are currently locked.

#####`snapshot_power_off_behaviour`
*Read Only* Whether to revert to a snapshot when the machine is powered
off.
