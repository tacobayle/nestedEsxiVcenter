//resource "null_resource" "vcenter_underlay_esxi_host_nic_update" {
//  depends_on = [null_resource.vcenter_configure2]
//  count = (var.vcenter.dvs.single_vds == false ? 1 : 0)
//  provisioner "local-exec" {
//    command = "/bin/bash esxi_host_nic_update.sh"
//  }
//}