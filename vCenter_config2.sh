#!/bin/bash
#
if [ -f "variables.json" ]; then
  jsonFile="variables.json"
else
  exit 1
fi
#
api_host="$(jq -r .vcenter.name $jsonFile).$(jq -r .dns.domain $jsonFile)"
vcenter_username=administrator
vcenter_domain=$(jq -r .vcenter.sso.domain_name $jsonFile)
vcenter_password=$TF_VAR_vcenter_password
#
load_govc_env () {
  export GOVC_USERNAME="$vcenter_username@$vcenter_domain"
  export GOVC_PASSWORD=$vcenter_password
  export GOVC_DATACENTER=$(jq -r .vcenter.datacenter $jsonFile)
  export GOVC_INSECURE=true
  export GOVC_CLUSTER=$(jq -r .vcenter.cluster $jsonFile)
  export GOVC_URL=$api_host
}
#
load_govc_esxi () {
  export GOVC_USERNAME="root"
  export GOVC_PASSWORD=$TF_VAR_esxi_root_password
  export GOVC_INSECURE=true
  unset GOVC_DATACENTER
  unset GOVC_CLUSTER
  unset GOVC_URL
}
#
#
# Cleaning unused Standard vswitch config and VM port group
#
echo "++++++++++++++++++++++++++++++++"
echo "Cleaning unused Standard vswitch config"
IFS=$'\n'
load_govc_esxi
echo ""
echo "++++++++++++++++++++++++++++++++"
for ip in $(cat $jsonFile | jq -c -r .vcenter.dvs.portgroup.management.esxi_ips[])
do
  export GOVC_URL=$ip
  echo "Deleting port group called VM Network for Host $ip"
  govc host.esxcli network vswitch standard portgroup remove -p "VM Network" -v "vSwitch0"
  echo "Deleting port group called Management Network for Host $ip"
  govc host.esxcli network vswitch standard portgroup remove -p "Management Network" -v "vSwitch0"
  echo "Deleting vswitch called vSwitch0 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch0
  echo "Deleting vswitch called vSwitch1 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch1
  echo "Deleting vswitch called vSwitch2 for Host $ip"
  govc host.esxcli network vswitch standard remove -v vSwitch2
done
#
# if single vds switch # add the second physical uplink
#
#if [[ $(jq -c -r .vcenter.dvs.single_vds $jsonFile) == true ]] ; then
#  load_govc_env
#  echo "++++++++++++++++++++++++++++++++"
#  for ip in $(jq -r .vcenter.dvs.portgroup.management.esxi_ips[] $jsonFile)
#  do
#    echo "Adding physical port vmnic1 for ESXi host $ip for VDS $(jq -r .vcenter.dvs.basename $jsonFile)-0"
#    govc dvs.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-0" -pnic=vmnic1 $ip
#  done
#fi
#
# VSAN Configuration
#
load_govc_env
echo "Enabling VSAN configuration"
govc cluster.change -drs-enabled -ha-enabled -vsan-enabled -vsan-autoclaim "$(jq -r .vcenter.cluster $jsonFile)"
IFS=$'\n'
count=0
for ip in $(jq -r .vcenter.dvs.portgroup.management.esxi_ips[] $jsonFile)
do
  load_govc_esxi
  if [[ $count -ne 0 ]] ; then
    export GOVC_URL=$ip
    echo "Adding host $ip in VSAN configuration"
    govc host.esxcli vsan storage tag add -t capacityFlash -d "$(jq -r .vcenter.capacity_disk $jsonFile)"
    govc host.esxcli vsan storage add --disks "$(jq -r .vcenter.capacity_disk $jsonFile)" -s "$(jq -r .vcenter.cache_disk $jsonFile)"
  fi
  count=$((count+1))
done
#
# readonly User config
#
#load_govc_env
#echo "Configure readonly vCenter user and allow readonly to everything"
#govc sso.user.create -p $TF_VAR_vcenter_readonly_password readonly; echo "Creating user readonly"
#govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /
#
# Avi User config
#
load_govc_env
echo "Configure Avi vCenter users"
if [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == true ]] ; then
  for username in $(cat attendees.txt); do govc sso.user.create -p $TF_VAR_vcenter_avi_password ${username%@*}; echo "Creating user ${username%@*}" ; done
fi
#
# Resource Group Config
#
load_govc_env
echo "Configure Resource Group"
if [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == true ]] ; then
  for username in $(cat attendees.txt)
    do
      username_wo_domain=${username%@*}
      username_wo_domain_wo_dot="${username_wo_domain//./_}"
      echo "Creating resource group $username_wo_domain_wo_dot"
      govc pool.create -cpu.limit=-1 -mem.limit=-1 */Resources/$username_wo_domain_wo_dot
      echo "Setting permission for username ${username%@*} for resource pool $username_wo_domain_wo_dot"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role Admin -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile)/Resources/$username_wo_domain_wo_dot
    done
fi
#
if [[ $(jq -c -r .avi.app.create $jsonFile) == true ]] ; then
  echo "Creating resource group avi_app"
  govc pool.create -cpu.limit=-1 -mem.limit=-1 */Resources/avi_app
  for username in $(cat attendees.txt)
    do
      username_wo_domain=${username%@*}
      username_wo_domain_wo_dot="${username_wo_domain//./_}"
      echo "Setting permission for username ${username%@*} for resource pool avi_app"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile)/Resources/avi_app
    done
fi
#
# Permission Config
#
load_govc_env
echo "Configure Permission for cluster and hosts access"
if [[ $(jq -c -r .vcenter.avi_users.create $jsonFile) == true ]] ; then
  for username in $(cat attendees.txt)
    do
      echo "Creating permission for resource / for ${username%@*}"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role Admin -propagate=false /
      echo "Creating permission for resource dc /$(jq -r .vcenter.datacenter $jsonFile) for ${username%@*}"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role Admin -propagate=false /$(jq -r .vcenter.datacenter $jsonFile)
      echo "Creating permission for resource cluster /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile) for ${username%@*}"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=false /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile)
      echo "Creating permission for resource datastore /$(jq -r .vcenter.datacenter $jsonFile)/datastore/vsanDatastore for ${username%@*}"
      govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=false /$(jq -r .vcenter.datacenter $jsonFile)/datastore/vsanDatastore
      #
      # Add ReadOnly permission for each host in the cluster
      #
      IFS=$'\n'
      count=1
      for ip in $(jq -r .vcenter.dvs.portgroup.management.esxi_ips[] $jsonFile)
        do
          echo "Creating permission for resource host /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile)/$(jq -r .esxi.basename $jsonFile)$count.$(jq -r .dns.domain $jsonFile) for ${username%@*}"
          govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=false /$(jq -r .vcenter.datacenter $jsonFile)/host/$(jq -r .vcenter.cluster $jsonFile)/$(jq -r .esxi.basename $jsonFile)$count.$(jq -r .dns.domain $jsonFile)
          count=$((count+1))
        done
    done
fi