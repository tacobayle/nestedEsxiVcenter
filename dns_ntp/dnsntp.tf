resource "vsphere_content_library" "library" {
  count = (var.dns_ntp.create == true ? 1 : 0)
  name            = var.vcenter_underlay.cl.name
  storage_backing = [data.vsphere_datastore.datastore.id]
}

resource "vsphere_content_library_item" "files" {
  count = (var.dns_ntp.create == true ? 1 : 0)
  name        = basename(var.vcenter_underlay.cl.file)
  library_id  = vsphere_content_library.library[0].id
  file_url = var.vcenter_underlay.cl.file
}

data "template_file" "dns_ntp_userdata" {
  count = (var.dns_ntp.create == true ? 1 : 0)
  template = file("${path.module}/userdata/dns_ntp.userdata")
  vars = {
    pubkey        = file(var.dns_ntp.public_key_path)
    username = var.dns_ntp.username
    ipCidr  = "${var.vcenter.dvs.portgroup.management.dns_ntp_ip}/${var.vcenter.dvs.portgroup.management.prefix}"
    ip = var.vcenter.dvs.portgroup.management.dns_ntp_ip
    lastOctet = split(".", var.vcenter.dvs.portgroup.management.dns_ntp_ip)[3]
    defaultGw = var.vcenter.dvs.portgroup.management.gateway
    dns      = var.dns_ntp.dns
    netplanFile = var.dns_ntp.netplanFile
    privateKey = var.dns_ntp.private_key_path
    forwarders = var.dns_ntp.bind.forwarders
    domain = var.dns.domain
    reverse = var.dns_ntp.bind.reverse
    keyName = var.dns_ntp.bind.keyName
    secret = base64encode(var.bind_password)
    ntp = var.dns_ntp.ntp
  }
}

resource "vsphere_virtual_machine" "dns_ntp" {
  count = (var.dns_ntp.create == true ? 1 : 0)
  name             = var.dns_ntp.name
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"
  network_interface {
    network_id = data.vsphere_network.vcenter_underlay_network_mgmt[0].id
  }

  num_cpus = var.dns_ntp.cpu
  memory = var.dns_ntp.memory
  wait_for_guest_net_timeout = var.dns_ntp.wait_for_guest_net_timeout
  guest_id = var.dns_ntp.name

  disk {
    size             = var.dns_ntp.disk
    label            = "${var.dns_ntp.name}.lab_vmdk"
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
      hostname    = var.dns_ntp.name
      public-keys = file(var.dns_ntp.public_key_path)
      user-data   = base64encode(data.template_file.dns_ntp_userdata[0].rendered)
    }
  }

  connection {
    host        = var.vcenter.dvs.portgroup.management.dns_ntp_ip
    type        = "ssh"
    agent       = false
    user        = var.dns_ntp.username
    private_key = file(var.dns_ntp.private_key_path)
  }

  provisioner "remote-exec" {
    inline      = [
      "while [ ! -f /tmp/cloudInitDone.log ]; do sleep 1; done"
    ]
  }
}