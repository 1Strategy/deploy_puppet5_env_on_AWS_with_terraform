#!/bin/bash

# Initialize the variables #
declare -x INPUT_JSON=$(cat <<EOF
'{
    "HostedZoneId": "${hosted_zone_id}", 
    "ChangeBatch": {
        "Comment": "Update the A record set", 
        "Changes": [
            {
                "Action": "UPSERT", 
                "ResourceRecordSet": {
                    "Name": "${master_hostname}", 
                    "Type": "A",            
                    "TTL": 300, 
                    "ResourceRecords": [
                        {
                            "Value": "$(curl --silent --show-error --retry 3 http://169.254.169.254/latest/meta-data/local-ipv4)"
                        }
                    ]
                }
            }
        ]
    }
}'
EOF
)

function mountefs {
    yum install -y amazon-efs-utils
    mkdir /etc/puppetlabs
    mount -t efs fs-de0ab596:/ ${efs_id}:/ /etc/puppetlabs
}

function installpuppet {
    rpm -Uvh ${puppet_repo}
    yum -y install puppetserver
    export PATH=/opt/puppetlabs/bin:$PATH

    ### Configure the puppet master ###
    puppet config set certname ${master_hostname} --section main
    puppet config set dns_alt_names puppet,${master_hostname} --section master
    puppet config set autosign true --section master

    echo "puppet is installed."
}

function backupmaster {
    echo "backing up puppetlabs folder"
    mkdir /tmp/puppetbackup
    rm -rf /tmp/puppetbackup/*
    cp -a /etc/puppetlabs/. /tmp/puppetbackup
}

function restoremaster {
    rm -rf /etc/puppetlabs/*
    cp -a /tmp/puppetbackup/. /etc/puppetlabs
    echo "puppet is recovered."
}

function generater10kconfig {
    if [ ! -f /etc/puppetlabs/r10k/r10k.yaml ]; then
        echo -e "\nGenerating a r10k.yaml file"

        # Generate default r10k.yaml 
        mkdir /etc/puppetlabs/r10k
        cat > /etc/puppetlabs/r10k/r10k.yaml <<EOL
---
:cachedir: '/var/cache/r10k'

:sources:
  :base:
    remote: '${r10k_repo}'
    basedir: '/etc/puppetlabs/code/environments'
EOL
    fi
}

function installr10k {
    yum -y install git
    export PATH=/opt/puppetlabs/puppet/bin:$PATH
    /opt/puppetlabs/puppet/bin/gem install r10k
}

export LC_ALL=C

# Set up the host name of the master node #
hostname ${master_hostname}

# Update the system #
yum -y update

# Create/Update DNS record of the puppet master node #
eval aws route53 change-resource-record-sets --cli-input-json $INPUT_JSON

# Mount EFS Volume #
mountefs

# Install Puppet#

## Folder /etc/puppetlabs is not empty, use existing puppet ##
if find /etc/puppetlabs -mindepth 1 -print -quit | grep -q .; then
    backupmaster
    installpuppet
    installr10k
    restoremaster

## Folder /etc/puppetlabs is empty, install and configure puppet master ##
else
    installpuppet
    installr10k
    generater10kconfig
fi

# Start the puppet master and add the service to start up #
systemctl start puppetserver
systemctl enable puppetserver
/opt/puppetlabs/puppet/bin/r10k deploy environment

puppet cert list --all