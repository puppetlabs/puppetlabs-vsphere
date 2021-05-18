# Change log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v2.0.0](https://github.com/puppetlabs/puppetlabs-vsphere/tree/v2.0.0) (2021-05-18)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/v1.6.0...v2.0.0)

### Changed

- pdksync - Remove Puppet 5 from testing and bump minimal version to 6.0.0 [\#203](https://github.com/puppetlabs/puppetlabs-vsphere/pull/203) ([carabasdaniel](https://github.com/carabasdaniel))

## [v1.6.0](https://github.com/puppetlabs/puppetlabs-vsphere/tree/v1.6.0) (2020-12-16)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/v1.5.0...v1.6.0)

### Added

- pdksync - \(feat\) - Add support for Puppet7 [\#197](https://github.com/puppetlabs/puppetlabs-vsphere/pull/197) ([daianamezdrea](https://github.com/daianamezdrea))
- pdksync - \(IAC-973\) - Update travis/appveyor to run on new default branch `main` [\#187](https://github.com/puppetlabs/puppetlabs-vsphere/pull/187) ([david22swan](https://github.com/david22swan))

### Fixed

- Update REFERENCE.md [\#196](https://github.com/puppetlabs/puppetlabs-vsphere/pull/196) ([ola-pt](https://github.com/ola-pt))

## [v1.5.0](https://github.com/puppetlabs/puppetlabs-vsphere/tree/v1.5.0) (2020-06-25)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/v1.4.0...v1.5.0)

### Added

- \(FM-8684\) - Addition of Support for CentOS 8 [\#169](https://github.com/puppetlabs/puppetlabs-vsphere/pull/169) ([david22swan](https://github.com/david22swan))
- pdksync - Add support on Debian10 [\#163](https://github.com/puppetlabs/puppetlabs-vsphere/pull/163) ([lionce](https://github.com/lionce))

## [v1.4.0](https://github.com/puppetlabs/puppetlabs-vsphere/tree/v1.4.0) (2019-08-14)

[Full Changelog](https://github.com/puppetlabs/puppetlabs-vsphere/compare/1.3.1...v1.4.0)

### Fixed

- Clarify installation dependencies [DOCUMENT-1001](https://github.com/puppetlabs/puppetlabs-vsphere/pull/152)
- CloneVM_Task - wait_for_progress and display report on progress [MODULES-9261](https://github.com/puppetlabs/puppetlabs-vsphere/pull/158)
- Failure to execute process via create_command with generalised windows template [MODULES-9674](https://github.com/puppetlabs/puppetlabs-vsphere/pull/160)

### Added

- Puppet-strings documentation [FM-7941](https://github.com/puppetlabs/puppetlabs-vsphere/pull/154)
- Redhat8 support [FM-8036](https://github.com/puppetlabs/puppetlabs-vsphere/pull/155)

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



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
