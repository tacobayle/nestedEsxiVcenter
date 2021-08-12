# nestedEsxiVcenter

## Goal

This Infrastructure as code will deploy nested ESXi/vCenter on the top of vCenter/NSX environment.

## Use cases

### Single VDS - if esxi.single_vswitch == true
In this use case, a single vds switch is configured in the nested vCenter with three port groups:
- Management
- Vmotion
- VSAN
Each port group is configured with a VLAN ID.
Two "physical" uplink NICs (per ESXi host) are connected to this single VDS.
These two NICs are connected to the underlay vCenter network defined in underlay_vcenter.network (leveraging 802.1q).

### Multiple VDS - if esxi.single_vswitch == false
In this use case, multiple vds switches are configured in the nested vCenter:
- dvs-0
- dvs-1-VMotion
- dvs-2-VSAN 
Each VDS switch is connected to a "physical" NIC will be connected to the underlay vCenter network defined in underlay_vcenter.network (leveraging 802.1q).
Each port group will be configured with a VLAN ID. 




### DNS NTP - if dns-ntp.create == true

#### prerequisites on the Linux machine
- OS VERSION
```
18.04.2 LTS (Bionic Beaver)
```
- TF VERSION
#### prerequisites on the Linux machine - Terraform



## variables

### non sensitive variables

All the non sensitive variables are stored in variables.json

### sensitive variables

All the sensitive variables are stored in environment variables as below:

export TF_VAR_esxi_root_password=******              # Nested ESXi root password
export TF_VAR_vsphere_username=******                # Underlay vCenter username
export TF_VAR_vsphere_password=******                # Underlay vCenter password
export TF_VAR_bind_password=******                   # Bind password