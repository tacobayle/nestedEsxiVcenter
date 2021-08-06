provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vcenter_underlay.server
  allow_unverified_ssl = true
}

provider "dns" {
  update {
    server        = var.dns-ntp.ip
    key_name      = "${var.dns-ntp.bind.keyName}."
    key_algorithm = "hmac-md5"
    key_secret    = base64encode(var.bind_password)
  }
}