#!/bin/bash
SCRIPT_PATH=$(pwd)
BASENAME_CMD="basename ${SCRIPT_PATH}"
SCRIPT_BASE_PATH=`eval ${BASENAME_CMD}`

if [ $SCRIPT_BASE_PATH = "vsphere" ]; then
  cd ../../../
fi

export pe_dist_dir=http://pe-releases.puppetlabs.lan/3.8.1/
export GEM_SOURCE=http://rubygems.delivery.puppetlabs.net

bundle exec beaker \
  --config test_run_scripts/vagrant/configs/centos-7-x86_64.cfg \
  --debug \
  --test tests \
  --preserve-host \
  --pre-suite pre-suite \
  --load-path lib \
  --timeout 360
