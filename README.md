# nestedEsxiVcenter

## Goal

This Infrastructure as code will deploy nested ESXi/vCenter on the top of vCenter environment.

## Use cases

### Single VDS - if esxi.single_vswitch == true
In this use case, a single vds switch is configured in the nested vCenter with three port groups:
- Management
- Vmotion
- VSAN

The following port groups are configured with a specific VLAN ID:
- vcenter.dvs.portgroup.management.name with VLAN id vcenter.dvs.portgroup.management.vlan 
- vcenter.dvs.portgroup.VMotion.name with VLAN id vcenter.dvs.portgroup.VMotion.vlan
- vcenter.dvs.portgroup.VSAN.name with VLAN id vcenter.dvs.portgroup.VSAN.vlan

Two "physical" uplink NICs (per ESXi host) are connected to this single VDS.
These two NICs are connected to the underlay vCenter network defined in underlay_vcenter.network (leveraging 802.1q).

### Multiple VDS - if esxi.single_vswitch == false
In this use case, multiple vds switches are configured in the nested vCenter:
- dvs-0 with a port group called vcenter.dvs.portgroup.management.name and a port group called "vcenter.dvs.portgroup.management.name"-vmk - connected to a "physical" uplink to the underlay network (vcenter_underlay.networks.management)
- dvs-1-VMotion with a port group called vcenter.dvs.portgroup.management.VMotion.name - connected to a "physical" uplink to the underlay network (vcenter_underlay.vmotion.management)
- dvs-2-VSAN with a port group called vcenter.dvs.portgroup.management.VSAN.name - connected to a "physical" uplink to the underlay network (vcenter_underlay.vsan.management)
Each VDS switch is connected to one "physical" uplink NIC will be connected to the underlay vCenter network defined in underlay_vcenter.network (leveraging 802.1q).

### DNS NTP Server creation - if dns-ntp.create == true

## prerequisites on the underlay environment
- vCenter underlay version:
```
6.7.0
```

## prerequisites on the Linux machine
- OS Version
```
18.04.2 LTS (Bionic Beaver)
```
- TF Version
```
Terraform v0.14.8
+ provider registry.terraform.io/hashicorp/dns v3.2.1
+ provider registry.terraform.io/hashicorp/local v2.1.0
+ provider registry.terraform.io/hashicorp/null v3.1.0
+ provider registry.terraform.io/hashicorp/template v2.2.0
+ provider registry.terraform.io/hashicorp/vsphere v2.0.2

Your version of Terraform is out of date! The latest version
is 1.0.4. You can update by downloading from https://www.terraform.io/downloads.html
```
- Ansible Version
```
ansible --version
[DEPRECATION WARNING]: Ansible will require Python 3.8 or newer on the controller starting with Ansible 2.12. Current
version: 2.7.17 (default, Feb 27 2021, 15:10:58) [GCC 7.5.0]. This feature will be removed from ansible-core in version
 2.12. Deprecation warnings can be disabled by setting deprecation_warnings=False in ansible.cfg.
/home/ubuntu/.local/lib/python2.7/site-packages/ansible/parsing/vault/__init__.py:44: CryptographyDeprecationWarning: Python 2 is no longer supported by the Python core team. Support for it is now deprecated in cryptography, and will be removed in a future release.
  from cryptography.exceptions import InvalidSignature
ansible [core 2.11.3]
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/ubuntu/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /home/ubuntu/.local/lib/python2.7/site-packages/ansible
  ansible collection location = /home/ubuntu/.ansible/collections:/usr/share/ansible/collections
  executable location = /home/ubuntu/.local/bin/ansible
  python version = 2.7.17 (default, Feb 27 2021, 15:10:58) [GCC 7.5.0]
  jinja version = 2.11.2
  libyaml = False
```
- govc Version
```
govc v0.24.0
```
- jq version
```
jq - commandline JSON processor [version 1.5-1-a5b5cbe]
```


## variables

### non sensitive variables

All the non sensitive variables are stored in variables.json

### sensitive variables

All the sensitive variables are stored in environment variables as below:

```bash
export TF_VAR_esxi_root_password=******              # Nested ESXi root password
export TF_VAR_vsphere_username=******                # Underlay vCenter username
export TF_VAR_vsphere_password=******                # Underlay vCenter password
export TF_VAR_bind_password=******                   # Bind password - needs to be defined even if if dns-ntp.create == true
```