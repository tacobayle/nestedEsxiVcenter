data "vsphere_datacenter" "dc_nested" {
//  depends_on = [null_resource.dual_uplink_update_multiple_vds, null_resource.dual_uplink_update_single_vds]
  count            = (var.avi.create_network == true ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  count            = (var.avi.create_network == true ? 1 : 0)
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
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name = "${var.vcenter.dvs.portgroup.avi_mgmt.name}_vds"
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
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name                            = var.vcenter.dvs.portgroup.avi_mgmt.name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_mgmt[0].id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_avi_vip" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name = "${var.vcenter.dvs.portgroup.avi_vip.name}_vds"
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
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name                            = var.vcenter.dvs.portgroup.avi_vip.name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_vip[0].id
  vlan_id = 0
}

resource "vsphere_distributed_virtual_switch" "network_avi_backend" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name = "${var.vcenter.dvs.portgroup.avi_backend.name}_vds"
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
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name                            = var.vcenter.dvs.portgroup.avi_backend.name
  distributed_virtual_switch_uuid = vsphere_distributed_virtual_switch.network_avi_backend[0].id
  vlan_id = 0
}


resource "null_resource" "update_network_permission" {
  depends_on = [vsphere_distributed_port_group.pg_avi_backend, vsphere_distributed_port_group.pg_avi_mgmt, vsphere_distributed_port_group.pg_avi_vip]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  provisioner "local-exec" {
    command = "cd bash; /bin/bash update_network_permission.sh"
  }
}

data "vsphere_network" "vcenter_network_mgmt_nested" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "time_sleep" "wait_10_seconds" {
  depends_on = [vsphere_distributed_port_group.pg_avi_vip]
  create_duration = "10s"
}

data "vsphere_network" "vcenter_network_avi_mgmt_nested" {
  depends_on = [time_sleep.wait_10_seconds]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create_network == true ? 1 : 0)
  name = "avi_mgmt"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_content_library" "nested_library_avi" {
  name            = "avi_controller"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
  description     = "avi_controller"
}

resource "vsphere_content_library_item" "aviController" {
  name        = basename(var.avi.ova_location)
  description = basename(var.avi.ova_location)
  library_id  = vsphere_content_library.nested_library_avi.id
  file_url = var.avi.ova_location
}

