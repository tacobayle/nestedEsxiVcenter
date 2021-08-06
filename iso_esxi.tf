resource "local_file" "ks_cust_single_vswicth" {
  count = (var.esxi.single_standard_vswitch == true ? var.esxi.count : 0)
  content     = templatefile("${path.module}/templates/ks_cust_single_vswicth.cfg.tmpl",
  { esxi_root_password = var.esxi_root_password,
    keyboard_type = var.esxi.keyboard_type,
    device_mgmt = var.esxi.device_mgmt,
    ip = var.esxi.ips_mgmt[count.index],
    netmask = var.vcenter_underlay.networks.management.netmask,
    gateway = var.vcenter_underlay.networks.management.gateway,
    ip_vmotion = var.esxi.ips_vmotion[count.index],
    netmask_vmotion = var.vcenter_underlay.networks.vmotion.netmask,
    ip_vsan = var.esxi.ips_vsan[count.index],
    netmask_vsan = var.vcenter_underlay.networks.vsan.netmask,
    ntp = var.ntp.server,
    nameserver = var.dns.nameserver,
    hostname = "${var.esxi.basename}-${count.index}.${var.dns.domain}"
    nic_amount = length(var.esxi.networks)
  }
  )
  filename = "${path.module}/ks_cust.cfg.${count.index}"
}

resource "local_file" "ks_cust_multiple_vswitch" {
  count = (var.esxi.single_standard_vswitch == false ? var.esxi.count : 0)
  content     = templatefile("${path.module}/templates/ks_cust_multiple_vswitch.cfg.tmpl",
  { esxi_root_password = var.esxi_root_password,
    keyboard_type = var.esxi.keyboard_type,
    device_mgmt = var.esxi.device_mgmt,
    ip = var.esxi.ips_mgmt[count.index],
    netmask = var.vcenter_underlay.networks.management.netmask,
    gateway = var.vcenter_underlay.networks.management.gateway,
    ip_vmotion = var.esxi.ips_vmotion[count.index],
    netmask_vmotion = var.vcenter_underlay.networks.vmotion.netmask,
    ip_vsan = var.esxi.ips_vsan[count.index],
    netmask_vsan = var.vcenter_underlay.networks.vsan.netmask,
    ntp = var.ntp.server,
    nameserver = var.dns.nameserver,
    hostname = "${var.esxi.basename}-${count.index}.${var.dns.domain}"
  }
  )
  filename = "${path.module}/ks_cust.cfg.${count.index}"
}

resource "null_resource" "iso_build" {
  depends_on = [local_file.ks_cust_single_vswicth, local_file.ks_cust_multiple_vswitch]
  provisioner "local-exec" {
    command = "/bin/bash iso_esxi_build.sh"
  }
}

resource "vsphere_file" "iso_upload" {
  depends_on = [null_resource.iso_build]
  count = var.esxi.count
  datacenter       = var.vcenter_underlay.dc
  datastore        = var.vcenter_underlay.datastore
  source_file      = "${var.esxi.iso_location}${count.index}.iso"
  destination_file = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
}

resource "null_resource" "iso_destroy" {
  depends_on = [vsphere_file.iso_upload]
  provisioner "local-exec" {
    command = "/bin/bash iso_esxi_destroy.sh"
  }
}