data "vsphere_datacenter" "dc_nested" {
  count            = (var.vcenter.dvs.single_vds == false ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_host" "host_nested" {
  count         = var.esxi.count
  name          = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_distributed_virtual_switch" "network_nsx_overlay" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name = var.vcenter.dvs.portgroup.nsx_overlay.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
  version = var.vcenter.dvs.version
  max_mtu = var.vcenter.dvs.portgroup.nsx_overlay.max_mtu

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic6"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_nsx_overlay" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name                            = "${var.vcenter.dvs.portgroup.nsx_overlay.name}-pg"
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_nsx_overlay[0].id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_nsx_external" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name = var.vcenter.dvs.portgroup.nsx_external.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
  version = var.vcenter.dvs.version
  max_mtu = var.vcenter.dvs.portgroup.nsx_external.max_mtu

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic7"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_nsx_external" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name                            = "${var.vcenter.dvs.portgroup.nsx_external.name}-pg"
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_nsx_external[0].id
  vlan_id = 0
}