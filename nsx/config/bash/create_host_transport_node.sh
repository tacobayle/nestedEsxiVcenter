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
#
# Retrieve session based details
#
curl -k -c cookies.txt -D headers.txt -X POST -d 'j_username=admin&j_password='$TF_VAR_nsx_password'' https://$nsx_ip/api/session/create
#
# create host transport node
#
compute_collections=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/api/v1/fabric/compute-collections)
IFS=$'\n'
for item in $(echo $compute_collections | jq -c -r .results[])
do
  if [[ $(echo $item | jq -r .display_name) == $(jq -r .vcenter.cluster $jsonFile) ]] ; then
    compute_collection_external_id=$(echo $item | jq -r .external_id)
  fi
done
transport_node_profiles=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/host-transport-node-profiles)
IFS=$'\n'
for item in $(echo $transport_node_profiles | jq -c -r .results[])
do
  if [[ $(echo $item | jq -r .display_name) == $(jq -r .nsx.config.transport_node_profiles[0].name $jsonFile) ]] ; then
    transport_node_profile_id=$(echo $item | jq -r .id)
  fi
done
curl -k -s -X POST -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" -d '{"resource_type": "TransportNodeCollection", "display_name": "TransportNodeCollection-1", "description": "Transport Node Collections 1", "compute_collection_id": "'$compute_collection_external_id'", "transport_node_profile_id": "'$transport_node_profile_id'"}' https://$nsx_ip/api/v1/transport-node-collections
#
# waiting for host transport node to be ready
#
sleep 60
discovered_nodes=$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes)
IFS=$'\n'
for item in $(echo $discovered_nodes | jq -c -r .results[])
do
  unique_id=$(echo $item | jq -c -r .unique_id)
  retry=10 ; pause=60 ; attempt=0
  while [[ "$(curl -k -s -X GET -b cookies.txt -o /dev/null -w ''%{http_code}'' -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state)" != "200" ]]; do
    echo "waiting for transport node status HTTP code to be 200"
    sleep $pause
    ((attempt++))
    if [ $attempt -eq $retry ]; then
      echo "FAILED to get NSX Manager API to be ready after $retry"
      exit 255
    fi
  done
  retry=10 ; pause=60 ; attempt=0
  while [[ "$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state | jq -r .deployment_progress_state.progress)" != 100 ]]; do
    echo "waiting for transport node deployment progress at 100%"
    sleep $pause
    ((attempt++))
    if [ $attempt -eq $retry ]; then
      echo "FAILED to get transport node deployment progress at 100% after $retry"
      exit 255
    fi
  done
  retry=10 ; pause=60 ; attempt=0
  while [[ "$(curl -k -s -X GET -b cookies.txt -H "`grep X-XSRF-TOKEN headers.txt`" -H "Content-Type: application/json" https://$nsx_ip/policy/api/v1/infra/sites/default/enforcement-points/default/host-transport-nodes/$unique_id/state | jq -r .state)" != "success" ]]; do
    echo "waiting for transport node status success"
    sleep $pause
    ((attempt++))
    if [ $attempt -eq $retry ]; then
      echo "FAILED to get transport node status success after $retry"
      exit 255
    fi
  done
done