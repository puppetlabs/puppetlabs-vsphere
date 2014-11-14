vsphere_machine { 'garethr-test':
  ensure   => present,
  template => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  memory   => 1024,
  cpus     => 1,
  vdc      => 'opdx1',
  folder   => 'eng',
}
