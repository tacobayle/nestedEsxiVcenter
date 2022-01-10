data "vsphere_datacenter" "dc" {
  name = var.vcenter_underlay.dc
}

data "vsphere_compute_cluster" "compute_cluster" {
  name          = var.vcenter_underlay.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name = var.vcenter_underlay.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = var.vcenter_underlay.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
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

data "vsphere_network" "vcenter_underlay_network_mgmt" {
  count = (var.vcenter.dvs.single_vds == false ? 1 : 0)
  name = var.vcenter_underlay.networks.management.name
  datacenter_id = data.vsphere_datacenter.dc.id
}

//resource "vsphere_folder" "esxi_folder" {
//  path          = var.vcenter_underlay.folder
//  type          = "vm"
//  datacenter_id = data.vsphere_datacenter.dc.id
//}

//data "vsphere_folder" "esxi_folder" {
//  path = "/${var.vcenter_underlay.dc}/${var.vcenter_underlay.datastore}/${var.vcenter_underlay.folder}"
//}