data "vsphere_datacenter" "dc_nested" {
  count            = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_host" "host_nested" {
  count         = var.esxi.count
  name          = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_distributed_virtual_switch" "network_nsx_overlay" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true && var.avi.networks.create == true ? 1 : 0)
  name = "${var.vcenter.dvs.portgroup.nsx_overlay.name}_vds"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic9"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_nsx_overlay" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true ? 1 : 0)
  name                            = var.vcenter.dvs.portgroup.nsx_overlay.name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_nsx_overlay[0].id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_nsx_overlay_wo_avi_networks" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true && var.avi.networks.create == false ? 1 : 0)
  name = "${var.vcenter.dvs.portgroup.nsx_overlay.name}_vds"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic6"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_nsx_overlay_wo_avi_networks" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.networks.create == true && var.avi.networks.create == false ? 1 : 0)
  name                            = var.vcenter.dvs.portgroup.nsx_overlay.name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_nsx_overlay[0].id
  vlan_id = 0
}