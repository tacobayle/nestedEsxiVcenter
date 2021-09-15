#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "variables.json file not found!!"
  exit 1
fi
#
if [ -f "../../attendees.txt" ]; then
  attendeesFile="../../attendees.txt"
else
  echo "attendees.txt file not found!!"
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
load_govc_env
for username in $(cat $attendeesFile)
do
  echo "Creating permission for resource vds /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_mgmt.name $jsonFile)_vds for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/"$(jq -r .vcenter.dvs.portgroup.avi_mgmt.name $jsonFile)_vds"
  echo "Creating permission for resource vds /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_vip.name $jsonFile)_vds for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/"$(jq -r .vcenter.dvs.portgroup.avi_vip.name $jsonFile)_vds"
  echo "Creating permission for resource vds /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_backend.name $jsonFile)_vds for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/"$(jq -r .vcenter.dvs.portgroup.avi_backend.name $jsonFile)_vds"
  echo "Creating permission for resource pg /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_mgmt.name $jsonFile) for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_mgmt.name $jsonFile)
  echo "Creating permission for resource pg /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_vip.name $jsonFile) for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_vip.name $jsonFile)
  echo "Creating permission for resource pg /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_backend.name $jsonFile) for ${username%@*} with ReadOnly mode"
  govc permissions.set -principal ${username%@*}@$vcenter_domain -role ReadOnly -propagate=true /$(jq -r .vcenter.datacenter $jsonFile)/network/$(jq -r .vcenter.dvs.portgroup.avi_backend.name $jsonFile)
done

# var.vcenter.dvs.portgroup.avi_backend.name