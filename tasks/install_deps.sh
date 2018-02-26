#!/bin/bash

/opt/puppetlabs/bin/puppet resource package rbvmomi ensure=present provider=puppet_gem
/opt/puppetlabs/bin/puppet resource package hocon ensure=present provider=puppet_gem
