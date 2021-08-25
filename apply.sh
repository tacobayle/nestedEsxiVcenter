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
# Build of a folder on the underlay infrastructure
#
echo "--------------------------------------------------------------------------------------------------------------------"
echo "Build of a folder on the underlay infrastructure"
cd vsphere_underlay_folder
terraform init
terraform apply -auto-approve -var-file=../$jsonFile
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of a DNS/NTP server on the underlay infrastructure
#
echo "Build of a DNS/NTP server on the underlay infrastructure"
if [[ $(jq -c -r .dns_ntp.create $jsonFile) == true ]] ; then
  cd dns_ntp
  terraform init
  terraform apply -auto-approve -var-file=../$jsonFile
  cd ..
fi
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of the nested ESXi/vCenter infrastructure
#
echo "Build of the nested ESXi/vCenter infrastructure"
terraform init ; terraform apply -auto-approve -var-file=variables.json
#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.create $jsonFile) == true ]] ; then
  cd nsx
  terraform init ; terraform apply -auto-approve -var-file=../$jsonFile
  cd ..
fi
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of Avi infrastructure
#
echo "Build of Avi infrastructure"
if [[ $(jq -c -r .avi.create $jsonFile) == true ]] ; then
  cd avi
  terraform init ; terraform apply -auto-approve -var-file=../$jsonFile
  cd ..
fi
echo "--------------------------------------------------------------------------------------------------------------------"