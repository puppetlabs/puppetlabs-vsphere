A very basic proof of concept for managing vSphere machines using the
Puppet DSL:

```puppet
vsphere_machine { 'garethr-test':
  ensure   => present,
  template => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  memory   => 1024,
  cpus     => 1,
  vdc      => 'opdx1',
  folder   => 'eng',
}
```

Also supports listing and managing machines via `puppet resource`:

    puppet resource vsphere_machine

and to delete the machine we created above:

    puppet resource vsphere_machine garethr-test ensure=absent
