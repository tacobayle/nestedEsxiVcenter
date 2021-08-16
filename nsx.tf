resource "vsphere_folder" "nsx" {
  provider        = vsphere.overlay
  count            = (var.nsx.create == true ? 1 : 0)
  path          = "nsx"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc_nested.id
}


resource "vsphere_virtual_machine" "nsx" {
  provider        = vsphere.overlay
  count            = (var.nsx.create == true ? 1 : 0)
  name             = "${var.nsx.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id
  folder           = vsphere_folder.nsx[0].path
  deployment_option = var.nsx.deployment

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  clone {
    template_uuid = vsphere_content_library_item.OvaNSX.id
  }

  vapp {
    properties = {
      nsx_allowSSHRootLogin = true
      nsx_cli_audit_passwd_0 = var.nsx_password
      nsx_cli_passwd_0 = var.nsx_password
      nsx_dns1_0 = var.dns.nameserver
      nsx_gateway_0 = var.vcenter.dvs.portgroup.management.gateway
      nsx_hostname = "${var.nsx.basename}-${count.index}"
      nsx_ip_0 = var.vcenter.dvs.portgroup.management.nsx_ip
      nsx_isSSHEnabled = true
      nsx_netmask_0 = var.vcenter.dvs.portgroup.management.netmask
      nsx_ntp_0 = var.ntp.server
      nsx_passwd_0 = var.nsx_password
      nsx_role = var.nsx.role
      nsx_swIntegrityCheck = false
    }
  }
}
