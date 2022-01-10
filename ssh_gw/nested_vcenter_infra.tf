data "vsphere_datacenter" "dc_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name = var.vcenter.datacenter
}

data "vsphere_compute_cluster" "compute_cluster_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name          = var.vcenter.cluster
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_datastore" "datastore_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name = "vsanDatastore"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_resource_pool" "resource_pool_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name          = "${var.vcenter.cluster}/Resources"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_network" "vcenter_network_mgmt_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_network" "vcenter_network_avi_mgmt_nested" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name = "avi_mgmt"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}