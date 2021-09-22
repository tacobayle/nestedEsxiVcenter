

resource "vsphere_virtual_machine" "controller" {
  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == false && var.avi.controller.create == true ? 1 : 0)
  name             = "${var.avi.controller.basename}-${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore_nested[0].id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested[0].id

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested[0].id
  }

  num_cpus = var.avi.controller.cpu
  memory = var.avi.controller.memory
  wait_for_guest_net_timeout = 4
  guest_id = "guestid-controller-${count.index + 1}"

  disk {
    size             = var.avi.controller.disk
    label            = "controller--${count.index + 1}.lab_vmdk"
    thin_provisioned = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_avi_item[0].id
  }

  vapp {
    properties = {
      "mgmt-ip"     = element(var.vcenter.dvs.portgroup.management.avi_ips, count.index)
      "mgmt-mask"   = var.vcenter.dvs.portgroup.management.netmask
      "default-gw"  = var.vcenter.dvs.portgroup.management.gateway
   }
 }
}

resource "null_resource" "wait_https_controller" {
  depends_on = [vsphere_virtual_machine.controller]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == false && var.avi.controller.create == true ? 1 : 0)

  provisioner "local-exec" {
    command = "until $(curl --output /dev/null --silent --head -k https://${element(var.vcenter.dvs.portgroup.management.avi_ips, count.index)}); do echo 'Waiting for Avi Controllers to be ready'; sleep 60 ; done"
  }
}

resource "null_resource" "add_nic_via_govc" {
  depends_on = [null_resource.wait_https_controller]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == false && var.avi.controller.create == true ? 1 : 0 && var.avi.networks.create == true ? 1 : 0)

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME='administrator@${var.vcenter.sso.domain_name}'
      export GOVC_PASSWORD=${var.vcenter_password}
      export GOVC_DATACENTER=${var.vcenter.datacenter}
      export GOVC_URL=${var.vcenter.name}.${var.dns.domain}
      export GOVC_CLUSTER=${var.vcenter.cluster}
      export GOVC_INSECURE=true
      govc vm.network.add -vm ${var.avi.controller.basename}-${count.index + 1} -net avi_mgmt
    EOT
  }
}

resource "null_resource" "ansible_init_controller" {
  depends_on = [null_resource.add_nic_via_govc]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == false && var.avi.controller.create == true ? 1 : 0)

  provisioner "local-exec" {
    command = "ansible-playbook ansible/init_controller.yml --extra-vars '{\"avi_ip\": ${jsonencode(element(var.vcenter.dvs.portgroup.management.avi_ips, count.index))}, \"avi_version\": ${split("-", basename(var.avi.content_library.ova_location))[1]}}'"
  }
}

resource "null_resource" "assign_new_ip" {
  depends_on = [null_resource.ansible_init_controller]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.manager.create == false && var.avi.controller.create == true ? 1 : 0 && var.avi.networks.create == true ? 1 : 0)

  connection {
    host        = element(var.vcenter.dvs.portgroup.management.avi_ips, count.index)
    type        = "ssh"
    agent       = false
    user        = "admin"
    password    = var.avi_password
  }

  provisioner "remote-exec" {
    inline      = [
      "echo \"${var.avi_password}\" | sudo -S ip link set dev eth1 up",
      "echo \"${var.avi_password}\" | sudo -S ip address add ${element(var.vcenter.dvs.portgroup.avi_mgmt.avi_ips, count.index)}/${var.vcenter.dvs.portgroup.avi_mgmt.prefix} dev eth1",
    ]
  }
}