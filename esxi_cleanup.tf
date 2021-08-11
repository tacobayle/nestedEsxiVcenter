resource "null_resource" "vcenter_underlay_esxi_host_nic_update" {
  depends_on = [null_resource.vcenter_configure2]
  count = (var.esxi.single_vswitch == false ? 1 : 0)
  provisioner "local-exec" {
    command = "/bin/bash esxi_host_nic_update.sh"
  }
}