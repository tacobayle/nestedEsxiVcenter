#!/bin/bash
#
if [ -f "../../variables.json" ]; then
  jsonFile="../../variables.json"
else
  echo "ERROR: no json file found"
  exit 1
fi
nsx_ip=$(jq -r .vcenter.dvs.portgroup.management.nsx_ip $jsonFile)
vcenter_username=administrator
vcenter_domain=$(jq -r .vcenter.sso.domain_name $jsonFile)
vcenter_fqdn="$(jq -r .vcenter.name $jsonFile).$(jq -r .dns.domain $jsonFile)"
rm -f cookies.txt headers.txt
curl -k -c cookies.txt -D headers.txt -X POST -d 'j_username=admin&j_password='$TF_VAR_nsx_password'' https://$nsx_ip/api/session/create
ValidCmThumbPrint=$(curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d '{"display_name": "'$vcenter_fqdn'", "server": "'$vcenter_fqdn'", "create_service_account": true, "access_level_for_oidc": "FULL", "origin_type": "vCenter", "set_as_oidc_provider" : true, "credential": {"credential_type": "UsernamePasswordLoginCredential", "username": "'$vcenter_username'@'$vcenter_domain'", "password": "'$TF_VAR_vcenter_password'"}}' https://$nsx_ip/api/v1/fabric/compute-managers | jq -r .error_data.ValidCmThumbPrint)
compute_manager=$(curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d '{"display_name": "'$vcenter_fqdn'", "server": "'$vcenter_fqdn'", "create_service_account": true, "access_level_for_oidc": "FULL", "origin_type": "vCenter", "set_as_oidc_provider" : true, "credential": {"credential_type": "UsernamePasswordLoginCredential", "username": "'$vcenter_username'@'$vcenter_domain'", "password": "'$TF_VAR_vcenter_password'", "thumbprint": "'$ValidCmThumbPrint'"}}' https://$nsx_ip/api/v1/fabric/compute-managers)
compute_manager_id=$(echo $compute_manager | jq -r .id)
retry=6
pause=10
attempt=0
while true ; do
  echo "waiting for compute manager to be UP and REGISTERED"
  compute_manager_runtime=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/fabric/compute-managers/$compute_manager_id/status)
  if [[ $(echo $compute_manager_runtime | jq -r .connection_status) == "UP" && $(echo $compute_manager_runtime | jq -r .registration_status) == "REGISTERED" ]] ; then
    echo "compute manager UP and REGISTERED"
    break
  fi
  if [ $attempt -eq $retry ]; then
    echo "FAILED to get compute manager UP and REGISTERED after $retry retries"
    exit 255
  fi
  sleep $pause
  ((attempt++))
done