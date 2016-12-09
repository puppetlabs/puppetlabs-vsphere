vsphere_vm { '/opdx1/vm/eng/garethr/garethr-test':
  ensure => present,
  source => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  memory => 512,
  cpus   => 2,
}

