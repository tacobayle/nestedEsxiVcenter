provider "vsphere" {
  user           = var.vsphere_username
  password       = var.vsphere_password
  vsphere_server = var.vcenter_underlay.server
  allow_unverified_ssl = true
}

provider "dns" {
  update {
    server        = var.vcenter.dvs.portgroup.management.dns-ntp_ip
    key_name      = "${var.dns-ntp.bind.keyName}."
    key_algorithm = "hmac-md5"
    key_secret    = base64encode(var.bind_password)
  }
}