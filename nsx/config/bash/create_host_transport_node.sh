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