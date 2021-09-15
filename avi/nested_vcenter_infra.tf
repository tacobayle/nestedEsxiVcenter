data "vsphere_datacenter" "dc_nested" {
//  depends_on = [null_resource.dual_uplink_update_multiple_vds, null_resource.dual_uplink_update_single_vds]
  count            = (var.avi.networks.create == true ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  count            = (var.avi.networks.create == true ? 1 : 0)
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

data "vsphere_network" "vcenter_network_mgmt_nested" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.networks.create == true ? 1 : 0)
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_network" "vcenter_network_avi_mgmt_nested" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.networks.create == true ? 1 : 0)
  name = "avi_mgmt"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_content_library" "nested_library_avi" {
  name            = "avi_controller"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
  description     = "avi_controller"
}

resource "vsphere_content_library_item" "aviController" {
  name        = basename(var.avi.controller.ova_location)
  description = basename(var.avi.controller.ova_location)
  library_id  = vsphere_content_library.nested_library_avi.id
  file_url = var.avi.controller.ova_location
}

