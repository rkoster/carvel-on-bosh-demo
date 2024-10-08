#!/bin/bash

set -eu -o pipefail

config="$(bosh cloud-config | spruce json | jq -c .)"

#export BOSH_vm_type="$(echo ${config} | bosh int --path /vm_types/1/name -)"
export BOSH_vm_type=e2-medium.disk
export BOSH_network="$(echo ${config} | bosh int --path /networks/2/name -)"
export BOSH_azs="$(echo ${config} | bosh int --path /networks/2/subnets/0/azs -)"

bosh -n deploy -d carvel-on-bosh-demo manifest/manifest.yml --vars-env=BOSH
