# Purging Unmanaged Virtual Machines

If you are using Puppet as the only tool to manage the machines in your
vSphere installation you can have Puppet automatically delete any
machines not specified in your manifest. This can be useful if you want
to enforce only one way of doing things.

Doing this uses the `resources`
[type](https://docs.puppetlabs.com/references/latest/type.html#resources)
and the associated `purge` parameter. This is described in the
documentation as follows:

> Whether to purge unmanaged resources. When set to true, this will delete
  any resource that is not specified in your configuration and is not
  autorequired by any managed resources

The example below shows this in use. Remember that this will *delete all your virtual
machines* apart from those described in the same manifest. Do not run
the following code on it's own.

```puppet
resources { 'vsphere_vm':
  purge => true,
}
```

A safer option is to run this with the `noop` parameter set to true.
This won't actually delete the unmanaged machines but will tell you
about machines it would have deleted. This means you can add them to
your manifest or delete them manually as needed.

```puppet
resources { 'vsphere_vm':
  purge => true,
  noop  => true,
}
```

This will output something similar in the logs (this example running
under debug):

```
Debug: Prefetching rbvmomi resources for vsphere_vm
Notice: /Stage[main]/Main/Vsphere_vm[/west1/vm/test]/ensure: current_value running, should be absent (noop)
Debug: Finishing transaction 70211596554260
Debug: Storing state
Debug: Stored state in 0.43 seconds
```
