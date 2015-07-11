#!/bin/bash
SCRIPT_PATH=$(pwd)
BASENAME_CMD="basename ${SCRIPT_PATH}"
SCRIPT_BASE_PATH=`eval ${BASENAME_CMD}`

if [ $SCRIPT_BASE_PATH = "vsphere" ]; then
  cd ../../../
fi

export pe_dist_dir=http://enterprise.delivery.puppetlabs.net/2015.2/ci-ready/
export GEM_SOURCE=http://rubygems.delivery.puppetlabs.net

bundle exec beaker \
  --config test_run_scripts/vagrant/configs/ubuntu-x86_64.cfg \
  --debug \
  --test tests \
  --preserve-host \
  --pre-suite pre-suite \
  --load-path lib \
  --timeout 360
