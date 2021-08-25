#!/bin/bash
#
# Script to run before TF
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  exit 1
fi
#
# Build of a DNS/NTP server on the underlay infrastructure
#
if [[ $(jq -c -r .dns-ntp.create $jsonFile) == true ]] ; then
  cd dns-ntp
  terraform init ; terraform apply auto-approve -var-file=../$jsonFile
  cd -
fi
#
# Build of the nested ESXi/vCenter infrastructure
#
terraform init ; terraform apply -auto-approve -var-file=variables.json
#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.create $jsonFile) == true ]] ; then
  cd nsx
  terraform init ; terraform apply auto-approve -var-file=../$jsonFile
  cd -
fi
#
# Build of Avi infrastructure
#
if [[ $(jq -c -r .avi.create $jsonFile) == true ]] ; then
  cd avi
  terraform init ; terraform apply auto-approve -var-file=../$jsonFile
  cd -
fi