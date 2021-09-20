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
  # $5 is var-file
  echo "--------------------------------------------------------------------------------------------------------------------"
  echo $1
  echo "starting timestamp: $(date)"
  cd $2
  terraform init > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Init errors:"
    cat $4
    exit 1
  else
    rm $3 $4
  fi
  terraform apply -auto-approve -var-file=$5 > $3 2>$4
  if [ -s "$4" ] ; then
    echo "TF Apply errors:"
    cat $3
    exit 1
  fi
  echo "ending timestamp: $(date)"
  cd -
  echo "--------------------------------------------------------------------------------------------------------------------"
}


#
# Build of a folder on the underlay infrastructure
#
tf_init_apply "Build of a folder on the underlay infrastructure - This should take less than a minute" vsphere_underlay_folder ../logs/tf_vsphere_underlay_folder.stdout ../logs/tf_vsphere_underlay_folder.errors ../$jsonFile
#echo "--------------------------------------------------------------------------------------------------------------------"
#echo "Build of a folder on the underlay infrastructure - This should take less than a minute"
#date
#cd vsphere_underlay_folder
#terraform init > ../logs/tf_init_vsphere_underlay_folder.stdout 2>../logs/tf_init_vsphere_underlay_folder.errors
#cat ../logs/tf_init_vsphere_underlay_folder.errors
#terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_vsphere_underlay_folder.stdout 2>../logs/tf_apply_vsphere_underlay_folder.errors
#if [ -s "../logs/tf_apply_vsphere_underlay_folder.errors" ]
#then
#  echo "TF errors:"
#  cat ../logs/tf_apply_vsphere_underlay_folder.errors
#  exit 1
#fi
#cd ..
#date
#echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of a DNS/NTP server on the underlay infrastructure
#
if [[ $(jq -c -r .dns_ntp.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of a DNS/NTP server on the underlay infrastructure - This should take less than 5 minutes" dns_ntp ../logs/tf_dns_ntp.stdout ../logs/tf_dns_ntp.errors ../$jsonFile
#  echo "Build of a DNS/NTP server on the underlay infrastructure - This should take less than 5 minutes"
#  date
#
#  cd dns_ntp
#  terraform init > ../logs/tf_init_dns_ntp.stdout 2>../logs/tf_init_dns_ntp.errors
#  cat ../logs/tf_init_dns_ntp.errors
#  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_dns_ntp.stdout 2>../logs/tf_apply_dns_ntp.errors
#  if [ -s "../logs/tf_apply_dns_ntp.errors" ]
#  then
#    echo "TF errors:"
#    cat ../logs/tf_apply_dns_ntp.errors
#    exit 1
#  fi
#  cd ..
#  date
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the nested ESXi/vCenter infrastructure
#
tf_init_apply "Build of the nested ESXi/vCenter infrastructure - This should take less than 45 minutes" nested_esxi_vcenter ../logs/tf_nested_esxi_vcenter.stdout ../logs/tf_nested_esxi_vcenter.errors ../$jsonFile
#date
#echo "Build of the nested ESXi/vCenter infrastructure - This should take less than 45 minutes"
#terraform init > logs/tf_init_nested_esxi_vcenter.stdout 2>logs/tf_init_nested_esxi_vcenter.errors
#cat logs/tf_init_nested_esxi_vcenter.errors
#terraform apply -auto-approve -var-file=variables.json > logs/tf_apply_nested_esxi_vcenter.stdout 2>logs/tf_apply_nested_esxi_vcenter.errors
#if [ -s "logs/tf_apply_nested_esxi_vcenter.errors" ]
#then
#  echo "TF errors:"
#  cat logs/tf_apply_nested_esxi_vcenter.errors
#  exit 1
#fi
echo "waiting for 15 minutes to finish the vCenter config..."
sleep 900
echo "--------------------------------------------------------------------------------------------------------------------"
#
# Build of the nested NSX-T appliance
#
if [[ $(jq -c -r .nsx.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of the nested NSXT infrastructure" nsx ../logs/tf_nsx.stdout ../logs/tf_nsx.errors ../$jsonFile
#  echo "Build of the nested NSXT infrastructure"
#  cd nsx
#  terraform init > ../logs/tf_init_nsx.stdout 2>../logs/tf_init_nsx.errors
#  cat ../logs/tf_init_avi.errors
#  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_nsx.stdout 2>../logs/tf_apply_nsx.errors
#  if [ -s "../logs/tf_apply_nsx.errors" ]
#  then
#    echo "TF errors:"
#    cat ../logs/tf_apply_nsx.errors
#    exit 1
#  fi
#  cd ..
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Avi Nested Networks
#
if [[ $(jq -c -r .avi.networks.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Avi Nested Networks - This should take less than a minute" avi/networks ../../logs/tf_avi_networks.stdout ../../logs/tf_avi_networks.errors ../../$jsonFile
#  echo "Build of Avi Nested Networks - This should take less than a minute"
#  date
#  cd avi/networks
#  terraform init > ../../logs/tf_init_avi_networks.stdout 2>../../logs/tf_init_avi_networks.errors
#  cat ../../logs/tf_init_avi_networks.errors
#  terraform apply -auto-approve -var-file=../../$jsonFile > ../../logs/tf_apply_avi_networks.stdout 2>../../logs/tf_apply_avi_networks.errors
#  if [ -s "../../logs/tf_apply_avi_networks.errors" ]
#  then
#    echo "TF errors:"
#    cat ../../logs/tf_apply_avi_networks.errors
#    exit 1
#  fi
#  cd ../..
#  date
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Nested Avi Controllers
#
if [[ $(jq -c -r .avi.controller.create $jsonFile) == true ]] || [[ $(jq -c -r .avi.content_library.create $jsonFile) == true ]] ; then
#  echo "Build of Nested Avi Controllers - This should take around 15 minutes"
#  date
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
#  cd avi
#  terraform init > ../logs/tf_init_avi.stdout 2>../logs/tf_init_avi.errors
#  cat ../logs/tf_init_avi.errors
#  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_avi.stdout 2>../logs/tf_apply_avi.errors
#  if [ -s "../logs/tf_apply_avi.errors" ]
#  then
#    echo "TF errors:"
#    cat ../logs/tf_apply_avi.errors
#    exit 1
#  fi
#  cd ..
#  date
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the Nested Avi App
#
if [[ $(jq -c -r .avi.app.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Nested Avi App - This should take less than 10 minutes" avi/app ../../logs/tf_avi_app.stdout ../../logs/tfavi_app.errors ../../$jsonFile
#  echo "Build of Nested Avi App - This should take less than 10 minutes"
#  date
#  cd avi/app
#  terraform init > ../../logs/tf_init_avi_app.stdout 2>../../logs/tf_init_avi_app.errors
#  cat ../../logs/tf_init_avi_app.errors
#  terraform apply -auto-approve -var-file=../../$jsonFile > ../../logs/tf_apply_avi_app.stdout 2>../../logs/tf_apply_avi_app.errors
#  if [ -s "../../logs/tf_apply_avi_app.errors" ]
#  then
#    echo "TF errors:"
#    cat ../../logs/tf_apply_avi_app.errors
#    exit 1
#  fi
#  cd ../..
#  date
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi
#
# Build of the ssg_gw
#
if [[ $(jq -c -r .ssh_gw.create $jsonFile) == true ]] ; then
  tf_init_apply "Build of Nested ssh_gw - This should take around 5 minutes" ssh_gw ../logs/tf_ssg_gw.stdout ../logs/tf_ssg_gw.errors ../$jsonFile
#  echo "Build of Nested ssh_gw - This should take around 5 minutes"
#  date
#  cd ssh_gw
#  terraform init > ../logs/tf_init_ssg_gw.stdout 2>../logs/tf_init_ssg_gw.errors
#  cat ../logs/tf_init_ssg_gw.errors
#  terraform apply -auto-approve -var-file=../$jsonFile > ../logs/tf_apply_ssg_gw.stdout 2>../logs/tf_apply_ssg_gw.errors
#  if [ -s "../logs/tf_apply_ssg_gw.errors" ]
#  then
#    echo "TF errors:"
#    cat ../logs/tf_apply_ssg_gw.errors
#    exit 1
#  fi
#  cd ..
#  date
#  echo "--------------------------------------------------------------------------------------------------------------------"
fi