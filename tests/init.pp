vsphere_machine { '/opdx1/vm/eng/garethr/garethr-test':
  ensure   => stopped,
  template => '/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  compute  => 'general1',
  memory   => 1024,
  cpus     => 1,
}
