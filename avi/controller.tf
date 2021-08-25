data "vsphere_network" "vcenter_network_mgmt_nested" {
  name = var.vcenter.dvs.portgroup.management.name
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

data "vsphere_network" "vcenter_network_avi_mgmt_nested" {
  depends_on = [vsphere_distributed_port_group.pg_avi_vip]
  name = "avi_mgmt"
  datacenter_id = data.vsphere_datacenter.dc_nested[0].id
}

resource "vsphere_content_library" "nested_library" {
  count = (var.avi.create == true ? 1 : 0)
  name            = "avi_controller"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
  description     = "avi_controller"
}

resource "vsphere_content_library_item" "aviController" {
  count = (var.avi.create == true ? 1 : 0)
  name        = basename(var.avi.ova_location)
  description = basename(var.avi.ova_location)
  library_id  = vsphere_content_library.nested_library[0].id
  file_url = var.avi.ova_location
}

resource "vsphere_virtual_machine" "controller" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create == true ? length(var.vcenter.dvs.portgroup.management.avi_ip) : 0)
  name             = "${var.avi.basename}-${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested.id
  }

  num_cpus = var.avi.cpu
  memory = var.avi.memory
  wait_for_guest_net_timeout = 4
  guest_id = "guestid-controller-${count.index + 1}"

  disk {
    size             = var.avi.disk
    label            = "controller--${count.index + 1}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.aviController[0].id
  }

  vapp {
    properties = {
      "mgmt-ip"     = element(var.vcenter.dvs.portgroup.management.avi_ip, count.index)
      "mgmt-mask"   = var.vcenter.dvs.portgroup.management.netmask
      "default-gw"  = var.vcenter.dvs.portgroup.management.gateway
   }
 }
}

resource "null_resource" "wait_https_controller" {
  depends_on = [vsphere_virtual_machine.controller]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create == true ? length(var.vcenter.dvs.portgroup.management.avi_ip) : 0)

  provisioner "local-exec" {
    command = "until $(curl --output /dev/null --silent --head -k https://${element(var.vcenter.dvs.portgroup.management.avi_ip, count.index)}); do echo 'Waiting for Avi Controllers to be ready'; sleep 20 ; done"
  }
}

resource "null_resource" "add_nic_via_govc" {
  depends_on = [null_resource.wait_https_controller]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create == true ? length(var.vcenter.dvs.portgroup.management.avi_ip) : 0)

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME='administrator@${var.vcenter.sso.domain_name}'
      export GOVC_PASSWORD=${var.vcenter_password}
      export GOVC_DATACENTER=${var.vcenter.datacenter}
      export GOVC_URL=${var.vcenter.name}.${var.dns.domain}
      export GOVC_CLUSTER=${var.vcenter.cluster}
      export GOVC_INSECURE=true
      govc vm.network.add -vm ${var.avi.basename}-${count.index + 1} -net avi_mgmt
    EOT
  }
}