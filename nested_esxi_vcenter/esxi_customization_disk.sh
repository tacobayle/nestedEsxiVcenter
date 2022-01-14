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
export GOVC_USERNAME=root
export GOVC_PASSWORD=$(echo $TF_VAR_esxi_root_password)
export GOVC_INSECURE=true
unset GOVC_DATACENTER
unset GOVC_CLUSTER
unset GOVC_URL
#
IFS=$'\n'
echo ""
echo "++++++++++++++++++++++++++++++++"
echo "Configure ESXi disks as SSD"
for ip in $(cat $jsonFile | jq -c -r .vcenter.dvs.portgroup.management.esxi_ips[])
do
  export GOVC_URL=$ip
  echo "+++++++++++++++++++"
  echo "Mark all disks as SSD for ESXi host $ip"
  EsxiMarkDiskAsSsd=$(govc host.storage.info -rescan | grep /vmfs/devices/disks | awk '{print $1}' | sort)
  for u in ${EsxiMarkDiskAsSsd[@]} ; do govc host.storage.mark -ssd $u ; done
done
