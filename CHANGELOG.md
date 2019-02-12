## [1.3.1](https://github.com/puppetlabs/puppetlabs-vsphere/tree/1.3.1) (2019-02-12)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/1.3.0...1.3.1)

### Fixed

- Updated license terms [#145](https://github.com/puppetlabs/puppetlabs-vsphere/pull/145) ([turbodog](https://github.com/turbodog))

## [1.3.0](https://github.com/puppetlabs/puppetlabs-vsphere/tree/1.3.0) (2018-11-26)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/1.2.2...1.3.0)

### Added

- Add Ubuntu Xenial to metadata [#118](https://github.com/puppetlabs/puppetlabs-vsphere/pull/118) ([eputnam](https://github.com/eputnam))
- (FM-6227) Add support for a datastore option [#124](https://github.com/puppetlabs/puppetlabs-vsphere/pull/124) ([jarretlavallee](https://github.com/jarretlavallee))
- (MODULES-5144) Prep for puppet 5 [#125](https://github.com/puppetlabs/puppetlabs-vsphere/pull/125) ([hunner](https://github.com/hunner))
- Adds task to install dependency gems for puppet server [#118](https://github.com/puppetlabs/puppetlabs-vsphere/pull/129) ([mrzarquon](https://github.com/mrzarquon))
- (FM-6637) Search nested Host and Clusters [#132](https://github.com/puppetlabs/puppetlabs-vsphere/pull/132) ([jarretlavallee](https://github.com/jarretlavallee))
- (MODULES-8294) - Update metadata support to Puppet 6 [#141](https://github.com/puppetlabs/puppetlabs-vsphere/pull/141) ([eimlav](https://github.com/eimlav))

### Fixed
- [FM-6971] Removal of unsupported OS from vsphere [#134](https://github.com/puppetlabs/puppetlabs-vsphere/pull/134) ([david22swan](https://github.com/david22swan))
- (FM-7082) - Update tests to fix CI [#139](https://github.com/puppetlabs/puppetlabs-vsphere/pull/139) ([eimlav](https://github.com/eimlav))

## Supported Version 1.2.2

This release includes:

* Documentation Updates
* Fixes failure when Datacenter has no VMs
* Fixes failure to load some instances when the compute resource is not a base ResourcePool or ClusterComputeResource
* Adds Debian 8 compatibility

## 2016-02-23 - Supported Version 1.2.1

This release includes:

* Test improvements
* Documentation updates.
* Fixes an issue where VM gets rebooted when managing CPU or Memory size
* Avoid an extra reboot during flush.
* Add acceptance testing to verify that the extra_config options are actually passed through to the API.
* Improve logging around restarting the machine when applying config
* Remove duplicate 'Creating machine' logging statement
* Compatibility update for hocon 1.0.0


## 2015-12-09 - Supported Version 1.2.0

This release includes:

* Large performance improvements, removing most of the per-VM API calls
* Better handling of resource pool selection
* Exposing more information to Puppet resource, including information
  about the underlying vCenter, associated datacenter, cpu and memory
  affinity rules and DRS behaviour

This release also fixes the following issues:

* Correct the display of the guest IP address in Puppet resource


## 2015-08-25 - Supported Version 1.1.0

This release includes:

* Performance improvements to prefetch
* Support for specifying a customization spec for new VMs

## 2015-07-21 - Supported Release 1.0.0

The first public release of the vSphere module provides basic support for
cloning and creating VMs and templates.

