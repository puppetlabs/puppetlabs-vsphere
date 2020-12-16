[![Build
Status](https://travis-ci.com/puppetlabs/puppetlabs-vsphere.svg?token=eSG6MMwAUKyfRwi9jMcv&branch=main)](https://travis-ci.org/puppetlabs/puppetlabs-vsphere)

# vsphere

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [Requirements](#requirements)
    * [Installing the vsphere module](#installing-the-vsphere-module)
    * [Getting Started with vSphere](#getting-started-with-vsphere)
4. [Usage](#usage)
    * [List and manage vSphere machines](#list-and-manage-vsphere-machines)
    * [Customize vSphere machines](#customize-vsphere-machines)
    * [Create linked clones](#create-linked-clones)
    * [Delete vSphere machines](#delete-vsphere-machines)
    * [Purge unmanaged virtual machines](#purge-unmanaged-virtual-machines)
5. [Reference](#reference)
    * [Types](#types)
    * [Parameters](#parameters)
6. [Limitations](#limitations)
7. [Development](#development)
8. [Known Issues](#known-issues)

# Overview

VMware vSphere is a cloud computing virtualization platform.

# Module Description

The vSphere module allows you to manage vSphere machines using Puppet.

# Setup

## Requirements

* Puppet Enterprise 3.7 or greater
* Ruby 1.9 or greater
* Rbvmomi Ruby gem 1.8 or greater
* vSphere 5.5 - 6.7

## Installing the vSphere module

The following are *dependencies* of the module. Install these on the system which you configure the module on. For example, in a server-agent setup, install the dependencies on the agent.

### On Debian 7 and 8, Ubuntu 14.04 LTS, and similar

1. Install the required dependencies:

  On Debian 7 and 8, Ubuntu 14.04 LTS and similar
  ```
  apt-get install zlib1g-dev libxslt1-dev build-essential
  ```

  On RHEL 6 and 7, CentOS, and similar
  ```
  yum install zlib-devel libxslt-devel patch gc gcc-c++ kernel-devel make
  ```

2. Install the required gems with this command:

  ```
  /opt/puppetlabs/puppet/bin/gem rbvmomi --no-ri --no-rdoc
  /opt/puppetlabs/puppet/bin/gem hocon --version='~>1.0.0' --no-ri --no-rdoc
  ``` 

  If you are running Puppet Enterprise 2015.2.0 you need to use the updated path:

  ```
  /opt/puppetlabs/puppet/bin/gem install rbvmomi --no-ri --no-rdoc
  /opt/puppetlabs/puppet/bin/gem install hocon --version='~>1.0.0' --no-ri --no-rdoc
  ```

**Note:** Example pins the hocon gem version to prevent possible incompatibilities.

#### Special Case for RHEL 7.x dervied Docker containers
It may be necessary to install the `nokogiri` gem first, **BEFORE** the `rbvmomi` and `hocon` gems.
It has been observed on RHEL 7.x derived OS Docker containers that the `nokogiri` gem installation fails if it is installed as part of the dependency resolution for the `rbvmomi` or `hocon` gems:
```
  /opt/puppetlabs/puppet/bin/gem install nokogiri --no-ri --no-rdoc
  /opt/puppetlabs/puppet/bin/gem rbvmomi --no-ri --no-rdoc
  /opt/puppetlabs/puppet/bin/gem hocon --version='~>1.0.0' --no-ri --no-rdoc
```

### Configuring credentials

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


# Usage

## List and manage vSphere machines

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

## Customize vSphere machines

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

## Create linked clones

You can also specify that a newly launched machine should be a linked clone. Linked clones share a disk with the source machine.

```
vsphere_vm { '/opdx1/vm/eng/sample':
  ensure       => present,
  source       => '/opdx1/vm/eng/source',
  linked_clone => true,
}
```

## Delete vSphere machines

You can also delete the machine we created above by setting the `ensure`
property to `absent` in the manifest or using `puppet resouce` like so:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=absent

To remove only the machine's definition, but leave the underlying configuration
and disk files in place, you can set `ensure` to `unregistered`:

    puppet resource vsphere_vm /opdx1/vm/eng/garethr-test ensure=unregistered

Please note that the module currently provides no mechanism to clean up the files left behind by this operation.

## Purge unmanaged virtual machines

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

## A note on datacenters

By default, this module uses the default datacenter for your installation. If this fails or if you have multiple virtual datacenters on vSphere, you can specify which datacenter you are managing using the `VCENTER_DATACENTER` environment variable like so:

`export VCENTER_DATACENTER=my-datacenter`

This can also be set in the config file as `datacenter`.

If the datacenter is nested within folders (groups) in vSphere, specify the full path to the datacenter, for example:

`export VCENTER_DATACENTER=Australia/Perth/DC1`

# Reference

For information on the classes and types, see the [REFERENCE.md](https://github.com/puppetlabs/puppetlabs-vsphere/blob/main/REFERENCE.md).

# Limitations

For an extensive list of supported operating systems, see [metadata.json](https://github.com/puppetlabs/puppetlabs-vsphere/blob/main/metadata.json)

The vSphere module is only available for Puppet Enterprise 3.7 and later. This module has been tested with vSphere 5.5.

# Development

To run the acceptance tests follow the instructions [here](https://github.com/puppetlabs/puppet_litmus/wiki/Tutorial:-use-Litmus-to-execute-acceptance-tests-with-a-sample-module-(MoTD)#install-the-necessary-gems-for-the-module).

This module was built by Puppet Labs specifically for use with Puppet Enterprise (PE).
Puppet modules on the Puppet Forge are open projects, and community contributions are essential for keeping them great. To contribute to Puppet projects, see our [module contribution guide.](https://github.com/puppetlabs/puppetlabs-vsphere/blob/main/CONTRIBUTING.md)

If you run into an issue with this module, or if you would like to request a feature, please [file a ticket](https://tickets.puppetlabs.com/browse/MODULES/).
If you have problems getting this module up and running, please [contact Support](http://puppetlabs.com/services/customer-support).

# Known Issues	

When using the vSphere module with the Puppet Server, you first need to	
ensure the module is successfully loaded. Run the Puppet agent on the server node, for instance, with `puppet agent	
-t`. If you do not do this, the first, and only the first, run of	
the `vsphere_vm` resource fails on the agent with the following error:	

 ```	
Error: Could not retrieve catalog from remote server: Error 400 on	
SERVER: Could not autoload puppet/type/vsphere_vm: Could not autoload	
puppet/provider/vsphere_vm/rbvmomi: no such file to load --	
puppet_x/puppetlabs/prefetch_error on node	
```