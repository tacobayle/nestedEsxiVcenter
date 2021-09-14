data "template_file" "avi_app_userdata" {
  count = (var.avi.app.create == true ? length(var.vcenter.dvs.portgroup.management.avi_app_ips) : 0)
  template = file("${path.module}/userdata/avi_app.userdata")
  vars = {
    username     = var.avi.app.username
    hostname     = "avi_app-${count.index}"
    pubkey       = file(var.avi.app.public_key_path)
    netplan_file  = var.avi.app.netplan_file
    prefix_mgmt = var.vcenter.dvs.portgroup.management.prefix
    ip_mgmt = element(var.vcenter.dvs.portgroup.management.avi_app_ips, count.index)
    default_gw = var.vcenter.dvs.portgroup.management.gateway
    dns = var.dns.nameserver
  }
}

resource "vsphere_virtual_machine" "avi_app" {
  count = (var.avi.app.create == true ? length(var.vcenter.dvs.portgroup.management.avi_app_ips) : 0)
  name             = "avi_app-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore_nested.id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested.id

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested[0].id
  }

  num_cpus = var.avi.app.cpu
  memory = var.avi.app.memory
  wait_for_guest_net_timeout = "4"
  guest_id = "avi_app-${count.index}"

  disk {
    size             = var.avi.app.disk
    label            = "avi_app${count.index}.lab_vmdk"
    thin_provisioned = true
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_item_avi_app[0].id
  }

  vapp {
    properties = {
      hostname    = "avi_app-${count.index}"
      public-keys = file(var.avi.app.public_key_path)
      user-data   = base64encode(data.template_file.avi_app_userdata[count.index].rendered)
    }
  }

  connection {
    host        = element(var.vcenter.dvs.portgroup.management.avi_app_ips, count.index)
    type        = "ssh"
    agent       = false
    user        = var.avi.app.username
    private_key = file(var.avi.app.private_key_path)
  }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}

resource "null_resource" "add_nic_avi_app_via_govc" {
  depends_on = [vsphere_virtual_machine.avi_app]
  count = (var.avi.app.create == true ? length(var.vcenter.dvs.portgroup.management.avi_app_ips) : 0)

  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME='administrator@${var.vcenter.sso.domain_name}'
      export GOVC_PASSWORD=${var.vcenter_password}
      export GOVC_DATACENTER=${var.vcenter.datacenter}
      export GOVC_URL=${var.vcenter.name}.${var.dns.domain}
      export GOVC_CLUSTER=${var.vcenter.cluster}
      export GOVC_INSECURE=true
      govc vm.network.add -vm "avi_app-${count.index}" -net ${var.vcenter.dvs.portgroup.avi_backend.name}
    EOT
  }
}

resource "null_resource" "update_ip_avi_app" {
  depends_on = [null_resource.add_nic_avi_app_via_govc]
  count = (var.avi.app.create == true ? length(var.vcenter.dvs.portgroup.management.avi_app_ips) : 0)

  connection {
    host        = element(var.vcenter.dvs.portgroup.management.avi_app_ips, count.index)
    type        = "ssh"
    agent       = false
    user        = var.avi.app.username
    private_key = file(var.avi.app.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "ifaceFirstName=`ip -o link show | awk -F': ' '{print $2}' | head -2 | tail -1`",
      "macFirst=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -2 | tail -1`",
      "ifaceLastName=`ip -o link show | awk -F': ' '{print $2}' | tail -1`",
      "macLast=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}'| tail -1`",
      "sudo cp ${var.avi.app.netplan_file} ${var.avi.app.netplan_file}.old",
      "echo \"network:\" | sudo tee ${var.avi.app.netplan_file}",
      "echo \"    ethernets:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"        $ifaceFirstName:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            addresses: [${element(var.vcenter.dvs.portgroup.management.avi_app_ips, count.index)}/${var.vcenter.dvs.portgroup.management.prefix}]\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"                macaddress: $macFirst\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            set-name: $ifaceFirstName\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            gateway4: ${var.vcenter.dvs.portgroup.management.gateway}\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            nameservers:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"              addresses: [${var.dns.nameserver}]\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"        $ifaceLastName:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            addresses: [${element(var.vcenter.dvs.portgroup.avi_backend.avi_app_ips, count.index)}/${var.vcenter.dvs.portgroup.avi_mgmt.prefix}]\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"                macaddress: $macLast\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"            set-name: $ifaceLastName\" | sudo tee -a ${var.avi.app.netplan_file}",
      "echo \"    version: 2\" | sudo tee -a ${var.avi.app.netplan_file}",
      "sudo netplan apply"
    ]
  }
}