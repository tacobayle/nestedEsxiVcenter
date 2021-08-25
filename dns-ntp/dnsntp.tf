resource "vsphere_content_library" "library" {
  count = (var.dns-ntp.create == true ? 1 : 0)
  name            = var.vcenter_underlay.cl.name
  storage_backing = [data.vsphere_datastore.datastore.id]
}

resource "vsphere_content_library_item" "files" {
  count = (var.dns-ntp.create == true ? 1 : 0)
  name        = basename(var.vcenter_underlay.cl.file)
  library_id  = vsphere_content_library.library[0].id
  file_url = var.vcenter_underlay.cl.file
}

data "template_file" "dnsntp_userdata" {
  count = (var.dns-ntp.create == true ? 1 : 0)
  template = file("${path.module}/userdata/dns-ntp.userdata")
  vars = {
    pubkey        = file(var.dns-ntp.public_key_path)
    username = var.dns-ntp.username
    ipCidr  = "${var.vcenter.dvs.portgroup.management.dns-ntp_ip}/${var.vcenter.dvs.portgroup.management.prefix}"
    ip = var.vcenter.dvs.portgroup.management.dns-ntp_ip
    lastOctet = split(".", var.vcenter.dvs.portgroup.management.dns-ntp_ip)[3]
    defaultGw = var.vcenter.dvs.portgroup.management.gateway
    dns      = var.dns-ntp.dns
    netplanFile = var.dns-ntp.netplanFile
    privateKey = var.dns-ntp.private_key_path
    forwarders = var.dns-ntp.bind.forwarders
    domain = var.dns.domain
    reverse = var.dns-ntp.bind.reverse
    keyName = var.dns-ntp.bind.keyName
    secret = base64encode(var.bind_password)
    ntp = var.dns-ntp.ntp
  }
}

resource "vsphere_virtual_machine" "dnsntp" {
  count = (var.dns-ntp.create == true ? 1 : 0)
  name             = var.dns-ntp.name
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = vsphere_folder.esxi_folder.path
  network_interface {
    network_id = data.vsphere_network.vcenter_underlay_network_mgmt[0].id
  }

  num_cpus = var.dns-ntp.cpu
  memory = var.dns-ntp.memory
  wait_for_guest_net_timeout = var.dns-ntp.wait_for_guest_net_timeout
  guest_id = var.dns-ntp.name

  disk {
    size             = var.dns-ntp.disk
    label            = "${var.dns-ntp.name}.lab_vmdk"
    thin_provisioned = true
  }

  cdrom {
    client_device = true
  }

  clone {
    template_uuid = vsphere_content_library_item.files[0].id
  }

  vapp {
    properties = {
      hostname    = var.dns-ntp.name
      public-keys = file(var.dns-ntp.public_key_path)
      user-data   = base64encode(data.template_file.dnsntp_userdata[0].rendered)
    }
  }

  connection {
    host        = var.vcenter.dvs.portgroup.management.dns-ntp_ip
    type        = "ssh"
    agent       = false
    user        = var.dns-ntp.username
    private_key = file(var.dns-ntp.private_key_path)
  }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}