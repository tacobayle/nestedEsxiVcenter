resource "dns_a_record_set" "esxi" {
  depends_on = [vsphere_virtual_machine.dnsntp]
  count = length(var.vcenter_underlay.networks.management.esxi_ips)
  zone  = "${var.dns.domain}."
  name  = "${var.esxi.basename}-${count.index}"
  addresses = [element(var.vcenter_underlay.networks.management.esxi_ips, count.index)]
  ttl = 60
}

resource "dns_ptr_record" "esxi" {
  depends_on = [vsphere_virtual_machine.dnsntp]
  count = length(var.vcenter_underlay.networks.management.esxi_ips)
  zone = "${var.dns-ntp.bind.reverse}.in-addr.arpa."
  name = split(".", element(var.vcenter_underlay.networks.management.esxi_ips, count.index))[3]
  ptr  = "${var.esxi.basename}-${count.index}.${var.dns.domain}."
  ttl  = 60
}

resource "dns_a_record_set" "vcenter" {
  depends_on = [vsphere_virtual_machine.dnsntp]
  zone  = "${var.dns.domain}."
  name  = var.vcenter.name
  addresses = [var.vcenter_underlay.networks.management.vcenter_ip]
  ttl = 60
}

resource "dns_ptr_record" "vcenter" {
  depends_on = [vsphere_virtual_machine.dnsntp]
  zone = "${var.dns-ntp.bind.reverse}.in-addr.arpa."
  name = split(".", var.vcenter_underlay.networks.management.vcenter_ip)[3]
  ptr  = "${var.vcenter.name}.${var.dns.domain}."
  ttl  = 60
}