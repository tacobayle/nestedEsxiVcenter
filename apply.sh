#!/bin/bash
#
# Script to run before TF
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  echo "variables.json file not found!!"
  exit 1
fi
#
# Prerequisites to be added
# govc install
# jq install
# pip3 install pyvmomi for Ansible
# check the files
#
# Build of a folder on the underlay infrastructure
#
echo "--------------------------------------------------------------------------------------------------------------------"
echo "Build of a folder on the underlay infrastructure"
cd vsphere_underlay_folder
terraform init > ../logs/tf_init_vsphere_underlay_folder.stdout 2>../logs/tf_init_vsphere_underlay_folder.errors
cat ../logs/tf_init_vsphere_underlay_folder.errors
terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_vsphere_underlay_folder.stdout 2>../logs/tf_apply_vsphere_underlay_folder.errors
cat ../logs/tf_apply_vsphere_underlay_folder.errors
cd ..
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of a DNS/NTP server on the underlay infrastructure
#
if [[ $(jq -c -r .dns_ntp.create $jsonFile) == true ]] ; then
  echo "Build of a DNS/NTP server on the underlay infrastructure"
  cd dns_ntp
  terraform init > ../logs/tf_init_dns_ntp.stdout 2>../logs/tf_init_dns_ntp.errors
  cat ../logs/tf_init_dns_ntp.errors
  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_dns_ntp.stdout 2>../logs/tf_apply_dns_ntp.errors
  cat ../logs/tf_apply_dns_ntp.errors
  cd ..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the nested ESXi/vCenter infrastructure
#
echo "Build of the nested ESXi/vCenter infrastructure"
terraform init > logs/tf_init_nested_esxi_vcenter.stdout 2>logs/tf_init_nested_esxi_vcenter.errors
cat logs/tf_init_nested_esxi_vcenter.errors
terraform apply -auto-approve -var-file=variables.json > logs/tf_apply_nested_esxi_vcenter.stdout 2>logs/tf_apply_nested_esxi_vcenter.errors
cat logs/tf_apply_nested_esxi_vcenter.errors
echo "waiting for 15 minutes to finish the vCenter config..."
sleep 900
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.create $jsonFile) == true ]] ; then
  echo "Build of the nested NSXT infrastructure"
  cd nsx
  terraform init > ../logs/tf_init_nsx.stdout 2>../logs/tf_init_nsx.errors
  cat ../logs/tf_init_avi.errors
  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_nsx.stdout 2>../logs/tf_apply_nsx.errors
  cat ../logs/tf_apply_nsx.errors
  cd ..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Avi Nested Networks
#
if [[ $(jq -c -r .avi.networks.create $jsonFile) == true ]] ; then
  echo "Build of Avi Nested Networks"
  cd avi/networks
  terraform init > ../../logs/tf_init_avi_networks.stdout 2>../../logs/tf_init_avi_networks.errors
  cat ../../logs/tf_init_avi_networks.errors
  terraform apply -auto-approve -var-file=../../$jsonFile > ../../logs/tf_apply_avi_networks.stdout 2>../../logs/tf_apply_avi_networks.errors
  cat ../../logs/tf_apply_avi_networks.errors
  cd ../..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Nested Avi Controllers
#
if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] || [[ $(jq -c -r .avi.content_library.create $jsonFile) == true ]] ; then
  echo "Build of Nested Avi Controllers"
  rm -f avi/controllers.tf avi/rp_attendees_* avi/controllers_attendees_*
  if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] && [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == true ]] && [[ -f "$(jq -c -r .vcenter.avi_users.file $jsonFile)" ]] ; then
    count=0
    for username in $(cat $(jq -c -r .vcenter.avi_users.file $jsonFile))
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
  fi
  if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] && [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == false ]] ; then
    cp avi/templates/controllers.tf avi/
  fi
  cd avi
  terraform init > ../logs/tf_init_avi.stdout 2>../logs/tf_init_avi.errors
  cat ../logs/tf_init_avi.errors
  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_avi.stdout 2>../logs/tf_apply_avi.errors
  cat ../logs/tf_apply_avi.errors
  cd ..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Nested Avi App
#
if [[ $(jq -c -r .avi.app.create $jsonFile) == true ]] ; then
  echo "Build of Nested Avi App"
  cd avi/app
  terraform init > ../../logs/tf_init_avi_app.stdout 2>../../logs/tf_init_avi_app.errors
  cat ../../logs/tf_init_avi_app.errors
  terraform apply -auto-approve -var-file=../../$jsonFile > ../../logs/tf_apply_avi_app.stdout 2>../../logs/tf_apply_avi_app.errors
  cat ./../logs/tf_apply_avi_app.errors
  cd ../..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the ssg_gw
#
if [[ $(jq -c -r .ssh_gw.create $jsonFile) == true ]] ; then
  echo "Build of Nested ssh_gw"
  cd ssh_gw
  terraform init > ../logs/tf_init_ssg_gw.stdout 2>../logs/tf_init_ssg_gw.errors
  cat ../logs/tf_init_ssg_gw.errors
  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_ssg_gw.stdout 2>../logs/tf_apply_ssg_gw.errors
  cat ../logs/tf_apply_ssg_gw.errors
  cd ..
  echo "--------------------------------------------------------------------------------------------------------------------"
fi