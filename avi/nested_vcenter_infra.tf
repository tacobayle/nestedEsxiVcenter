data "vsphere_datacenter" "dc_nested" {
//  depends_on = [null_resource.dual_uplink_update_multiple_vds, null_resource.dual_uplink_update_single_vds]
  count            = (var.avi.create == true ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  count            = (var.avi.create == true ? 1 : 0)
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_datastore" "datastore_nested" {
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_host" "host_nested" {
  count         = var.esxi.count
  name          = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_distributed_virtual_switch" "network_avi_mgmt" {
  name = "avi_mgmt_dvs"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id

  //  uplinks         = ["uplink1", "uplink2", "uplink3", "uplink4"]
  //  active_uplinks  = ["uplink1", "uplink2"]
  //  standby_uplinks = ["uplink3", "uplink4"]

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic6"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_avi_mgmt" {
  name                            = "avi_mgmt"
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_mgmt.id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_avi_vip" {
  name = "avi_vip_dvs"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id

  //  uplinks         = ["uplink1", "uplink2", "uplink3", "uplink4"]
  //  active_uplinks  = ["uplink1", "uplink2"]
  //  standby_uplinks = ["uplink3", "uplink4"]

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic7"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_avi_vip" {
  name                            = "avi_vip"
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_vip.id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_avi_backend" {
  name = "avi_backend_dvs"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id

  //  uplinks         = ["uplink1", "uplink2", "uplink3", "uplink4"]
  //  active_uplinks  = ["uplink1", "uplink2"]
  //  standby_uplinks = ["uplink3", "uplink4"]

  dynamic "host" {
    for_each = data.vsphere_host.host_nested
    content {
      host_system_id = host.value.id
      devices        = ["vmnic8"]
    }
  }
}

resource "vsphere_distributed_port_group" "pg_avi_backend" {
  name                            = "avi_backend"
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_backend.id
  vlan_id = 0
}



//data "vsphere_network" "vcenter_network_mgmt_nested" {
//  provider        = vsphere.overlay
//  name = var.vcenter.dvs.portgroup.management.name
//  datacenter_id = data.vsphere_datacenter.dc_nested.id
//}