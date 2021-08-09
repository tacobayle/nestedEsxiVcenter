resource "vsphere_virtual_machine" "esxi_multiple_vswitch" {
  depends_on = [ vsphere_file.iso_upload ]
  count = (var.esxi.single_vswitch == false ? var.esxi.count : 0)
  name             = "${var.esxi.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = vsphere_folder.esxi_folder.path

  dynamic "network_interface" {
    for_each = data.vsphere_network.esxi_networks
    content {
      network_id = network_interface.value["id"]
    }
  }

  dynamic "network_interface" {
    for_each = data.vsphere_network.esxi_networks
    content {
      network_id = network_interface.value["id"]
    }
  }

  num_cpus = var.esxi.cpu
  memory = var.esxi.memory
  guest_id = var.esxi.guest_id
  wait_for_guest_net_timeout = var.esxi.wait_for_guest_net_timeout
  nested_hv_enabled = var.esxi.nested_hv_enabled
  firmware = var.esxi.bios

  dynamic "disk" {
    for_each = var.esxi.disks
    content {
      size = disk.value["size"]
      label = "${var.esxi.basename}-${count.index}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "vsphere_virtual_machine" "esxi_single_vswitch" {
  depends_on = [ vsphere_file.iso_upload ]
  count = (var.esxi.single_vswitch == true ? var.esxi.count : 0)
  name             = "${var.esxi.basename}-${count.index}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = vsphere_folder.esxi_folder.path

  network_interface {
    network_id = data.vsphere_network.esxi_network[0].id
  }

  network_interface {
    network_id = data.vsphere_network.esxi_network[0].id
  }

  num_cpus = var.esxi.cpu
  memory = var.esxi.memory
  guest_id = var.esxi.guest_id
  wait_for_guest_net_timeout = var.esxi.wait_for_guest_net_timeout
  nested_hv_enabled = var.esxi.nested_hv_enabled
  firmware = var.esxi.bios

  dynamic "disk" {
    for_each = var.esxi.disks
    content {
      size = disk.value["size"]
      label = "${var.esxi.basename}-${count.index}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "null_resource" "wait_esxi_multiple_vswitch" {
  depends_on = [vsphere_virtual_machine.esxi_multiple_vswitch]
  count = (var.esxi.single_vswitch == false ? var.esxi.count : 0)

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter_underlay.networks.management.esxi_ips[count.index]}); do echo \"Attempt $count: Waiting for ESXi host ${count.index} to be reachable...\"; sleep 40 ; count=$((count+1)) ;  if [ \"$count\" = 30 ]; then echo \"ERROR: Unable to connect to ESXi host\" ; exit 1 ; fi ; done"
  }
}

resource "null_resource" "wait_esxi_single_vswitch" {
  depends_on = [vsphere_virtual_machine.esxi_single_vswitch]
  count = (var.esxi.single_vswitch == true ? var.esxi.count : 0)

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter_underlay.network.esxi_ips[count.index]}); do echo \"Attempt $count: Waiting for ESXi host ${count.index} to be reachable...\"; sleep 40 ; count=$((count+1)) ;  if [ \"$count\" = 30 ]; then echo \"ERROR: Unable to connect to ESXi host\" ; exit 1 ; fi ; done"
  }
}

resource "null_resource" "esxi_customization" {
  depends_on = [null_resource.wait_esxi_multiple_vswitch, null_resource.wait_esxi_single_vswitch]

  provisioner "local-exec" {
    command = "/bin/bash esxi_customization.sh"
  }
}

resource "null_resource" "vcenter_underlay_clean_up" {
  depends_on = [null_resource.esxi_customization]

  provisioner "local-exec" {
    command = "/bin/bash vcenter_underlay_clean_up.sh"
  }
}

resource "null_resource" "vcenter_install" {
  depends_on = [null_resource.esxi_customization, vsphere_virtual_machine.dnsntp]

  provisioner "local-exec" {
    command = "/bin/bash iso_extract_vCenter.sh"
  }
}

resource "null_resource" "wait_vsca" {
  depends_on = [null_resource.vcenter_install]

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter_underlay.networks.management.vcenter_ip}); do echo \"Attempt $count: Waiting for vCenter to be reachable...\"; sleep 10 ; count=$((count+1)) ;  if [ \"$count\" = 30 ]; then echo \"ERROR: Unable to connect to vCenter\" ; exit 1 ; fi ; done"
  }
}

resource "null_resource" "vcenter_configure" {
  depends_on = [null_resource.wait_vsca]

  provisioner "local-exec" {
    command = "/bin/bash vCenter_config.sh"
  }
}

resource "null_resource" "esxi_host_nic_update" {
  depends_on = [null_resource.vcenter_configure]
  count = (var.esxi.single_vswitch == false ? 1 : 0)
  provisioner "local-exec" {
    command = "/bin/bash esxi_host_nic_update.sh"
  }
}