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
sleep 60
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
if [[ $(jq -c -r .esxi.single_vswitch $jsonFile) == true ]] ; then
  echo "++++++++++++++++++++++++++++++++"
  for ip in $(jq -r .vcenter.dvs.portgroup.management.esxi_ips[] $jsonFile)
  do
    echo "Adding physical port vmnic1 for ESXi host $ip for VDS $(jq -r .vcenter.dvs.basename $jsonFile)-0"
    govc dvs.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-0" -pnic=vmnic1 $ip
  done
fi