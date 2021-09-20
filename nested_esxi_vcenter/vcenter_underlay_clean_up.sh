#!/bin/bash
#
#
# Check if govc is installed
#
#if ! command -v govc &> /dev/null
#then
#    cd /usr/local/bin
#    sudo wget https://github.com/vmware/govmomi/releases/download/v0.24.0/govc_linux_amd64.gz
#    sudo gunzip govc_linux_amd64.gz
#    sudo mv govc_linux_amd64 govc
#    sudo chmod +x govc
#fi
##
#echo ""
#echo "++++++++++++++++++++++++++++++++"
#echo "Installing packages"
#sudo apt install -y jq
#
if [ -f "../variables.json" ]; then
  jsonFile="../variables.json"
else
  exit 1
fi
#
export GOVC_DATACENTER=$(cat $jsonFile | jq -r .vcenter_underlay.dc)
export GOVC_USERNAME=$(echo $TF_VAR_vsphere_username)
export GOVC_PASSWORD=$(echo $TF_VAR_vsphere_password)
export GOVC_URL=$(cat $jsonFile | jq -r .vcenter_underlay.server)
export GOVC_INSECURE=true
export GOVC_DATASTORE=$(cat $jsonFile | jq -r .vcenter_underlay.datastore)
count=$(cat $jsonFile | jq -r .esxi.count)
iso_location=$(cat $jsonFile | jq -r .esxi.iso_location)
#
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Cleaning Datastore"
for esx in $(seq 0 $(expr $count - 1))
do
  echo "+++++++++++++++++++"
  echo "Removing isos/$(basename $iso_location)$esx.iso"
  govc datastore.rm "isos/$(basename $iso_location)$esx.iso"
done
