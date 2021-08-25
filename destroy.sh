#!/bin/bash
#
# Script to destroy the infrastructure
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  exit 1
fi
#
# Destroy DNS/NTP server on the underlay infrastructure
#
if [[ $(jq -c -r .dns-ntp.create $jsonFile) == true ]] ; then
  cd dns-ntp
  terraform destroy auto-approve -var-file=../$jsonFile
  cd -
fi
#
# Destroy the nested ESXi/vCenter infrastructure
#
terraform refresh -var-file=variables.json ; terraform destroy -auto-approve -var-file=variables.json