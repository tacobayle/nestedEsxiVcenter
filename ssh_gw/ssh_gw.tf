data "template_file" "ssh_gw_userdata" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  template = file("${path.module}/userdata/ssh_gw.userdata")
  vars = {
    username     = var.ssh_gw.username
    hostname     = "ssh_gw"
    pubkey       = file(var.ssh_gw.public_key_path)
    netplan_file  = var.ssh_gw.netplan_file
    prefix_mgmt = var.vcenter.dvs.portgroup.management.prefix
    ip_mgmt = var.vcenter.dvs.portgroup.management.ssh_gw_ip
    default_gw = var.vcenter.dvs.portgroup.management.gateway
    dns = var.dns.nameserver
  }
}

resource "vsphere_virtual_machine" "ssh_gw" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name             = "ssh_gw"
  datastore_id     = data.vsphere_datastore.datastore_nested[0].id
  resource_pool_id = data.vsphere_resource_pool.resource_pool_nested[0].id

  network_interface {
    network_id = data.vsphere_network.vcenter_network_mgmt_nested[0].id
  }

//  network_interface {
//    network_id = data.vsphere_network.vcenter_network_avi_mgmt_nested[0].id
//  }

  num_cpus = var.ssh_gw.cpu
  memory = var.ssh_gw.memory
  wait_for_guest_net_timeout = "4"
  guest_id = "ssh_gw"

  disk {
    size             = var.ssh_gw.disk
    label            = "ssh_gw.lab_vmdk"
    thin_provisioned = true
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = vsphere_content_library_item.nested_library_item_ssh_gw[0].id
  }

  vapp {
    properties = {
      hostname    = "ssh_gw"
      public-keys = file(var.ssh_gw.public_key_path)
      user-data   = base64encode(data.template_file.ssh_gw_userdata[count.index].rendered)
    }
  }

  connection {
    host        = var.vcenter.dvs.portgroup.management.ssh_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.ssh_gw.username
    private_key = file(var.ssh_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}

resource "null_resource" "add_nic_ssh_gw_via_govc" {
  depends_on = [vsphere_virtual_machine.ssh_gw]
  count = (var.ssh_gw.create == true && var.avi.networks.create == true ? 1 : 0)
  provisioner "local-exec" {
    command = <<-EOT
      export GOVC_USERNAME='administrator@${var.vcenter.sso.domain_name}'
      export GOVC_PASSWORD=${var.vcenter_password}
      export GOVC_DATACENTER=${var.vcenter.datacenter}
      export GOVC_URL=${var.vcenter.name}.${var.dns.domain}
      export GOVC_CLUSTER=${var.vcenter.cluster}
      export GOVC_INSECURE=true
      govc vm.network.add -vm "ssh_gw" -net ${var.vcenter.dvs.portgroup.avi_vip.name}
      govc vm.network.add -vm "ssh_gw" -net ${var.vcenter.dvs.portgroup.avi_backend.name}
      govc vm.network.add -vm "ssh_gw" -net ${var.vcenter.dvs.portgroup.avi_mgmt.name}
    EOT
  }
}

resource "null_resource" "update_ip_ssh_gw" {
  depends_on = [null_resource.add_nic_ssh_gw_via_govc]
  count = (var.ssh_gw.create == true && var.avi.networks.create == true ? 1 : 0)

  connection {
    host        = var.vcenter.dvs.portgroup.management.ssh_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.ssh_gw.username
    private_key = file(var.ssh_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "ifaceFirstName=`ip -o link show | awk -F': ' '{print $2}' | head -2 | tail -1`",
      "macFirst=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -2 | tail -1`",
      "ifaceSecondName=`ip -o link show | awk -F': ' '{print $2}' | head -3 | tail -1`",
      "macSecond=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -3 | tail -1`",
      "ifaceThirdName=`ip -o link show | awk -F': ' '{print $2}' | head -4 | tail -1`",
      "macThird=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}' | head -4 | tail -1`",
      "ifaceLastName=`ip -o link show | awk -F': ' '{print $2}' | tail -1`",
      "macLast=`ip -o link show | awk -F'link/ether ' '{print $2}' | awk -F' ' '{print $1}'| tail -1`",
      "sudo cp ${var.ssh_gw.netplan_file} ${var.ssh_gw.netplan_file}.old",
      "echo \"network:\" | sudo tee ${var.ssh_gw.netplan_file}",
      "echo \"    ethernets:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"        $ifaceFirstName:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            addresses: [${var.vcenter.dvs.portgroup.management.ssh_gw_ip}/${var.vcenter.dvs.portgroup.management.prefix}]\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"                macaddress: $macFirst\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            set-name: $ifaceFirstName\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            gateway4: ${var.vcenter.dvs.portgroup.management.gateway}\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            nameservers:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"              addresses: [${var.dns.nameserver}]\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"        $ifaceSecondName:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            addresses: [${var.vcenter.dvs.portgroup.avi_vip.ssh_gw_ip}/${var.vcenter.dvs.portgroup.avi_vip.prefix}]\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"                macaddress: $macSecond\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            set-name: $ifaceSecondName\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"        $ifaceThirdName:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            addresses: [${var.vcenter.dvs.portgroup.avi_backend.ssh_gw_ip}/${var.vcenter.dvs.portgroup.avi_backend.prefix}]\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"                macaddress: $macThird\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            set-name: $ifaceThirdName\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"        $ifaceLastName:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            dhcp4: false\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            addresses: [${var.vcenter.dvs.portgroup.avi_mgmt.ssh_gw_ip}/${var.vcenter.dvs.portgroup.avi_mgmt.prefix}]\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            match:\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"                macaddress: $macLast\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"            set-name: $ifaceLastName\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "echo \"    version: 2\" | sudo tee -a ${var.ssh_gw.netplan_file}",
      "sudo netplan apply"
    ]
  }
}

resource "null_resource" "create_ssh_key_ssh_gw" {
  depends_on = [null_resource.update_ip_ssh_gw]
  count = (var.ssh_gw.create == true ? 1 : 0)

  connection {
    host        = var.vcenter.dvs.portgroup.management.ssh_gw_ip
    type        = "ssh"
    agent       = false
    user        = var.ssh_gw.username
    private_key = file(var.ssh_gw.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -b 2048 -t rsa -f /home/${var.ssh_gw.username}/.ssh/onpremsshkey -q -N \"\""
    ]
  }
}