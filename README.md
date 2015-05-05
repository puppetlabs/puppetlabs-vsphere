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

~~~
vsphere_machine { '/opdx1/vm/eng/garethr-test':
  ensure   => present,
  template => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  compute  => 'general1',
  memory   => 1024,
  cpus     => 1,
}
~~~

The module also supports listing and managing machines via `puppet resource`:

    puppet resource vsphere_machine

and you can even delete the machine we created above:

    puppet resource vsphere_machine /opdx1/vm/eng/garethr-test ensure=absent


## Usage

## References

### Types

* `vsphere_machine`: Manages a vpshere virtual machine.

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
*Required* The path within the specificed datacenter to the template to
base the new virtual machine on.

#####`memory`
The amount of memory to allocate to the new machine. Defaults to the
same as the template.

#####`cpus`
The number of CPUs to allocate to the new machine. Defaults to the
same as the template.


