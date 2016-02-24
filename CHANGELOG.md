##2016-02-23 - Supported Version 1.2.1

This release includes:

* Test improvements
* Documentation updates.
* Fixes an issue where VM gets rebooted when managing CPU or Memory size
* Avoid an extra reboot during flush.
* Add acceptance testing to verify that the extra_config options are actually passed through to the API.
* Improve logging around restarting the machine when applying config
* Remove duplicate 'Creating machine' logging statement
* Compatibility update for hocon 1.0.0


##2015-12-09 - Supported Version 1.2.0

This release includes:

* Large performance improvements, removing most of the per-VM API calls
* Better handling of resource pool selection
* Exposing more information to Puppet resource, including information
  about the underlying vCenter, associated datacenter, cpu and memory
  affinity rules and DRS behaviour

This release also fixes the following issues:

* Correct the display of the guest IP address in Puppet resource


##2015-08-25 - Supported Version 1.1.0

This release includes:

* Performance improvements to prefetch
* Support for specifying a customization spec for new VMs

##2015-07-21 - Supported Release 1.0.0

The first public release of the vSphere module provides basic support for
cloning and creating VMs and templates.

