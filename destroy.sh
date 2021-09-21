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
echo "Destroy DNS/NTP server on the underlay infrastructure"
if [[ $(jq -c -r .dns_ntp.create $jsonFile) == true ]] ; then
  cd dns_ntp
  terraform destroy -auto-approve -var-file=../$jsonFile
  cd ..
fi
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy the nested ESXi/vCenter infrastructure
#
echo "Destroy the nested ESXi/vCenter infrastructure"
cd nested_esxi_vcenter
terraform refresh -var-file=variables.json ; terraform destroy -auto-approve -var-file=variables.json
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Destroy of a folder on the underlay infrastructure
#
echo "--------------------------------------------------------------------------------------------------------------------"
echo "Build of a folder on the underlay infrastructure"
cd vsphere_underlay_folder
terraform init
terraform destroy -auto-approve -var-file=../$jsonFile
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"