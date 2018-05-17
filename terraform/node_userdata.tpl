#!/bin/bash

export LC_ALL=C

yum -y update
rpm -Uvh ${puppet_repo}
yum -y install puppet-agent
export PATH=/opt/puppetlabs/bin:$PATH

puppet config set server ${master_hostname} --section main

puppet resource service puppet ensure=running enable=true
