#!/bin/bash
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
export GOVC_USERNAME=$TF_VAR_vsphere_username
export GOVC_PASSWORD=$TF_VAR_vsphere_password
export GOVC_DATACENTER=$(jq -r .vcenter_underlay.dc $jsonFile)
export GOVC_INSECURE=true
export GOVC_CLUSTER=$(jq -r .vcenter_underlay.cluster $jsonFile)
export GOVC_URL="$(jq -r .vcenter_underlay.server $jsonFile)"
#
IFS=$'\n'
echo ""
echo "++++++++++++++++++++++++++++++++"
count=1
for ip in $(jq -c -r .vcenter.dvs.portgroup.management.esxi_ips[] $jsonFile)
do
  echo "removing vnic3 from ESXI $ip"
  govc device.remove -vm "$(jq -c -r .esxi.basename $jsonFile)$count" ethernet-3
  echo "removing vnic4 from ESXI $ip"
  govc device.remove -vm "$(jq -c -r .esxi.basename $jsonFile)$count" ethernet-4
  echo "removing vnic5 from ESXI $ip"
  govc device.remove -vm "$(jq -c -r .esxi.basename $jsonFile)$count" ethernet-5
  count=$((count+1))
done
