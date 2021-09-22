data "vsphere_datacenter" "dc_nested" {
//  depends_on = [null_resource.dual_uplink_update_multiple_vds, null_resource.dual_uplink_update_single_vds]
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_datastore" "datastore_nested" {
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}


data "vsphere_network" "vcenter_network_mgmt_nested" {
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

//data "vsphere_host" "host_nested" {
//  count         = var.esxi.count
//  name          = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
//  datacenter_id = data.vsphere_datacenter.dc_nested.id
//}
//
//resource "vsphere_distributed_virtual_switch" "network_nsx_overlay" {
//  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == true ? 1 : 0)
//  name = "${var.vcenter.dvs.portgroup.nsx_overlay.name}_vds"
//  datacenter_id = data.vsphere_datacenter.dc_nested.id
//
//  //  uplinks         = ["uplink1", "uplink2", "uplink3", "uplink4"]
//  //  active_uplinks  = ["uplink1", "uplink2"]
//  //  standby_uplinks = ["uplink3", "uplink4"]
//
//  dynamic "host" {
//    for_each = data.vsphere_host.host_nested
//    content {
//      host_system_id = host.value.id
//      devices        = ["vmnic9"]
//    }
//  }
//}
//
//resource "vsphere_distributed_port_group" "pg_nsx_overlay" {
//  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == true ? 1 : 0)
//  name                            = var.vcenter.dvs.portgroup.nsx_overlay.name
//  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_nsx_overlay[0].id
//  vlan_id = 0
//}