vsphere_machine { '/opdx1/vm/eng/garethr/garethr-test':
  ensure => absent,
  source => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  memory => 1024,
  cpus   => 2,

}
vsphere_machine { '/opdx1/vm/eng/garethr/garethr-template':
  ensure   => present,
  source   => '/opdx1/vm/eng/templates/debian-wheezy-3.2.0.4-amd64-vagrant-vmtools_9349',
  template => true,
}
