- create esxi with 4 interfaces (pnic0 and pnic3 should be bind to the same network)
- run the following:
```
if [[ $(jq -c -r .esxi.single_standard_vswitch $jsonFile) == false ]] ; then
  govc dvs.create -mtu $(jq -r .vcenter.dvs.mtu $jsonFile) -discovery-protocol $(jq -r .vcenter.dvs.discovery_protocol $jsonFile) "$(jq -r .vcenter.dvs.basename $jsonFile)-0-mgmt"
  govc dvs.create -mtu $(jq -r .vcenter.dvs.mtu $jsonFile) -discovery-protocol $(jq -r .vcenter.dvs.discovery_protocol $jsonFile) "$(jq -r .vcenter.dvs.basename $jsonFile)-1-VMotion"
  govc dvs.create -mtu $(jq -r .vcenter.dvs.mtu $jsonFile) -discovery-protocol $(jq -r .vcenter.dvs.discovery_protocol $jsonFile) "$(jq -r .vcenter.dvs.basename $jsonFile)-2-VSAN"
  govc dvs.portgroup.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-0-mgmt" -vlan 0 "$(jq -r .vcenter.dvs.portgroup.management.name $jsonFile)"
  govc dvs.portgroup.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-0-mgmt" -vlan 0 "$(jq -r .vcenter.dvs.portgroup.management.name $jsonFile)-vmk"
  govc dvs.portgroup.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-1-VMotion" -vlan 0 "$(jq -r .vcenter.dvs.portgroup.VMotion.name $jsonFile)"
  govc dvs.portgroup.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-2-VSAN" -vlan 0 "$(jq -r .vcenter.dvs.portgroup.VSAN.name $jsonFile)"
  IFS=$'\n'
  for ip in $(jq -r .esxi.ips_mgmt[] $jsonFile)
  do
    govc dvs.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-0-mgmt" -pnic=vmnic0 $ip
    govc dvs.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-1-VMotion" -pnic=vmnic1 $ip
    govc dvs.add -dvs "$(jq -r .vcenter.dvs.basename $jsonFile)-2-VSAN" -pnic=vmnic2 $ip
  done

fi
```
- moving the vmk0 to VDS:
```yaml
- hosts: localhost
  tasks:

#    - name: Migrate uplinks to the VDS
#      vmware_dvs_host:
#        hostname: 10.41.134.135
#        username: administrator@mydomain.com
#        password: Avi_2021
#        validate_certs: false
#        esxi_hostname: 10.41.134.131
#        switch_name: dvs-0-mgmt
#        vmnics:
#          - vmnic3
#        state: present


    - name: Migrate vmk0 to the VDS
      vmware_migrate_vmk:
        hostname: 10.41.134.135
        username: administrator@mydomain.com
        password: ******
        validate_certs: false
        esxi_hostname: 10.41.134.131
        device: 'vmk0'
        current_switch_name: 'vSwitch0'
        current_portgroup_name: 'Management Network'
        migrate_switch_name: dvs-0-mgmt
        migrate_portgroup_name: management-vmk
```
- migrating vcenter to port group mgmt:
```
govc vm.network.change -vm $(jq -r .vcenter.name $jsonFile) -net $(jq -r .vcenter.dvs.portgroup.management.name $jsonFile) ethernet-0
```
- cleaning:
remove port group and vswitch and unused vmnic
```
Usage: govc host.portgroup.remove [OPTIONS] NAME

Remove portgroup from HOST.

Examples:
  govc host.portgroup.remove bridge

Options:
  -host=                 Host system [GOVC_HOST]

```

```
Usage: govc host.vswitch.remove [OPTIONS] NAME

Options:
  -host=                 Host system [GOVC_HOST]
```

