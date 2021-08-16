data "vsphere_datacenter" "dc_nested" {
  depends_on = [null_resource.dual_uplink_update_multiple_vds, null_resource.dual_uplink_update_single_vds]
  provider        = vsphere.overlay
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  provider        = vsphere.overlay
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_datastore" "datastore_nested" {
  provider        = vsphere.overlay
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  provider        = vsphere.overlay
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

//data "vsphere_network" "esxi_networks" {
//  count = (var.vcenter.dvs.single_vds == false ? length(values(var.vcenter_underlay.networks)) : 0)
//  name = values(var.vcenter_underlay.networks)[count.index].name
//  datacenter_id = data.vsphere_datacenter.dc.id
//}
//
//data "vsphere_network" "esxi_network" {
//  count = (var.vcenter.dvs.single_vds == true ? 1 : 0)
//  name = var.vcenter_underlay.network.name
//  datacenter_id = data.vsphere_datacenter.dc.id
//}
//
data "vsphere_network" "vcenter_network_mgmt_nested" {
  provider        = vsphere.overlay
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}

//resource "vsphere_folder" "esxi_folder" {
//  path          = var.vcenter_underlay.folder
//  type          = "vm"
//  datacenter_id = data.vsphere_datacenter.dc.id
//}
//
//resource "vsphere_content_library" "library" {
//  count = (var.dns-ntp.create == true ? 1 : 0)
//  name            = var.vcenter_underlay.cl.name
//  storage_backing = [data.vsphere_datastore.datastore.id]
//}
//
//resource "vsphere_content_library_item" "files" {
//  count = (var.dns-ntp.create == true ? 1 : 0)
//  name        = basename(var.vcenter_underlay.cl.file)
//  library_id  = vsphere_content_library.library[0].id
//  file_url = var.vcenter_underlay.cl.file
//}