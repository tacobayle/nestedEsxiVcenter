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
terraform init
terraform apply -auto-approve -var-file=variables.json
#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.create $jsonFile) == true ]] ; then
  cd nsx
  terraform init
  terraform apply -auto-approve -var-file=../$jsonFile
  cd ..
fi
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of the Avi infrastructure
#
echo "Build of Avi infrastructure"
if [[ $(jq -c -r .avi.create_controller $jsonFile) == true ]] ; then
  rm -f avi/controllers.tf avi/rp_attendees_* avi/controllers_attendees_*
  if [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == true ]] && [[ -f "attendees.txt" ]]
  then
    count=0
    for username in $(cat attendees.txt)
    do
      username_wo_domain=${username%@*}
      username_wo_domain_wo_dot="${username_wo_domain//./_}"
      jq -n \
          --arg username $username_wo_domain_wo_dot \
          '{username: $username}' | tee config.json >/dev/null
          python3 python/template.py avi/templates/rp_attendees.tf.j2 config.json avi/rp_attendees_$username_wo_domain_wo_dot.tf
          rm config.json
      #
      jq -n \
          --arg username $username_wo_domain_wo_dot \
          --arg ip_controller $(jq -c -r .vcenter.dvs.portgroup.management.avi_ips[$count] $jsonFile) \
          --arg ip_controller_sec $(jq -c -r .vcenter.dvs.portgroup.avi_mgmt.avi_ips[$count] $jsonFile) \
          '{username: $username, ip_controller: $ip_controller, ip_controller_sec: $ip_controller_sec}' | tee config.json > /dev/null
          python3 python/template.py avi/templates/controllers_attendees.tf.j2 config.json avi/controllers_attendees_$username_wo_domain_wo_dot.tf
          rm config.json
          #
      count=$((count+1))
    done
    cp avi/templates/nested_content_library_ubuntu.tf avi/
    cp avi/templates/ssh_gw.tf avi/
  else
    cp avi/templates/controllers.tf avi/
  fi
fi
cd avi
terraform init
terraform apply -auto-approve -var-file=../$jsonFile
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"