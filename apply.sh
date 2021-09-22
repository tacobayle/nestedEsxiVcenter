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
tf_init_apply () {
  # $1 messsage to display
  # $2 is the folder to init/apply tf
  # $3 is the log path file for tf stdout
  # $4 is the log path file for tf error
  # $5 is var-file to feed TF with variables
  echo "-----------------------------------------------------"
  echo $1
  echo "Starting timestamp: $(date)"
  cd $2
  terraform init > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Init ERRORS:"
    cat $4
    exit 1
  else
    rm $3 $4
  fi
  terraform apply -auto-approve -var-file=$5 > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Apply ERRORS:"
    cat $4
    exit 1
  fi
  echo "Ending timestamp: $(date)"
  cd - > /dev/null
}


#
# Build of a folder on the underlay infrastructure
#
tf_init_apply "Build of a folder on the underlay infrastructure - This should take less than a minute" vsphere_underlay_folder ../logs/tf_vsphere_underlay_folder.stdout ../logs/tf_vsphere_underlay_folder.errors ../$jsonFile
#
# Build of a DNS/NTP server on the underlay infrastructure
#
if [[ $(jq -c -r .dns_ntp.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of a DNS/NTP server on the underlay infrastructure - This should take less than 5 minutes" dns_ntp ../logs/tf_dns_ntp.stdout ../logs/tf_dns_ntp.errors ../$jsonFile
fi
#
# Build of the nested ESXi/vCenter infrastructure
#
tf_init_apply "Build of the nested ESXi/vCenter infrastructure - This should take less than 45 minutes" nested_esxi_vcenter ../logs/tf_nested_esxi_vcenter.stdout ../logs/tf_nested_esxi_vcenter.errors ../$jsonFile
echo "waiting for 15 minutes to finish the vCenter config..."
sleep 900
#
# Build of the NSX Nested Networks
#
if [[ $(jq -c -r .nsx.networks.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of NSX Nested Networks - This should take less than a minute" nsx/networks ../../logs/tf_nsx_networks.stdout ../../logs/tf_nsx_networks.errors ../../$jsonFile
fi

#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.manager.create $jsonFile) == true ]] || [[ $(jq -c -r .nsx.content_library.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the nested NSXT infrastructure" nsx/manager ../../logs/tf_nsx.stdout ../../logs/tf_nsx.errors ../../$jsonFile
fi
#
# Build of the config of NSX-T
#
if [[ $(jq -c -r .nsx.config.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the config of NSX-T" nsx/config ../../logs/tf_nsx_config.stdout ../../logs/tf_nsx_config.errors ../../$jsonFile
fi
#
# Build of the Avi Nested Networks
#
if [[ $(jq -c -r .avi.networks.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Avi Nested Networks - This should take less than a minute" avi/networks ../../logs/tf_avi_networks.stdout ../../logs/tf_avi_networks.errors ../../$jsonFile
fi
#
# Build of the Nested Avi Controllers
#
if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] || [[ $(jq -c -r .avi.content_library.create $jsonFile) == true ]] ; then
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
  tf_init_apply "Build of Nested Avi Controllers - This should take around 15 minutes" avi ../logs/tf_avi.stdout ../logs/tf_avi.errors ../$jsonFile
fi
#
# Build of the Nested Avi App
#
if [[ $(jq -c -r .avi.app.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Nested Avi App - This should take less than 10 minutes" avi/app ../../logs/tf_avi_app.stdout ../../logs/tfavi_app.errors ../../$jsonFile
fi
#
# Build of the ssg_gw
#
if [[ $(jq -c -r .ssh_gw.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Nested ssh_gw - This should take around 5 minutes" ssh_gw ../logs/tf_ssg_gw.stdout ../logs/tf_ssg_gw.errors ../$jsonFile
fi