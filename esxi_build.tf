resource "local_file" "ks_cust_single_vswitch" {
  count = (var.vcenter.dvs.single_vds == true ? var.esxi.count : 0)
  content     = templatefile("${path.module}/templates/ks_cust_single_vswitch.cfg.tmpl",
  { esxi_root_password = var.esxi_root_password,
    keyboard_type = var.esxi.keyboard_type,
    ip = var.vcenter.dvs.portgroup.management.esxi_ips[count.index],
    netmask = var.vcenter.dvs.portgroup.management.netmask,
    gateway = var.vcenter.dvs.portgroup.management.gateway,
    ip_vmotion = var.vcenter.dvs.portgroup.VMotion.esxi_ips[count.index],
    netmask_vmotion = var.vcenter.dvs.portgroup.VMotion.netmask,
    ip_vsan = var.vcenter.dvs.portgroup.VSAN.esxi_ips[count.index],
    netmask_vsan = var.vcenter.dvs.portgroup.VSAN.netmask,
    ntp = var.ntp.server,
    nameserver = var.dns.nameserver,
    hostname = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
  }
  )
  filename = "${path.module}/ks_cust.cfg.${count.index}"
}

resource "local_file" "ks_cust_multiple_vswitch" {
  count = (var.vcenter.dvs.single_vds == false ? var.esxi.count : 0)
  content     = templatefile("${path.module}/templates/ks_cust_multiple_vswitch.cfg.tmpl",
  { esxi_root_password = var.esxi_root_password,
    keyboard_type = var.esxi.keyboard_type,
    ip = var.vcenter.dvs.portgroup.management.esxi_ips[count.index],
    netmask = var.vcenter.dvs.portgroup.management.netmask,
    gateway = var.vcenter.dvs.portgroup.management.gateway,
    ip_vmotion = var.vcenter.dvs.portgroup.VMotion.esxi_ips[count.index],
    netmask_vmotion = var.vcenter.dvs.portgroup.VMotion.netmask,
    ip_vsan = var.vcenter.dvs.portgroup.VSAN.esxi_ips[count.index],
    netmask_vsan = var.vcenter.dvs.portgroup.VSAN.netmask,
    ntp = var.ntp.server,
    nameserver = var.dns.nameserver,
    hostname = "${var.esxi.basename}${count.index + 1}.${var.dns.domain}"
  }
  )
  filename = "${path.module}/ks_cust.cfg.${count.index}"
}

resource "null_resource" "iso_build" {
  depends_on = [local_file.ks_cust_single_vswitch, local_file.ks_cust_multiple_vswitch]
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

resource "vsphere_virtual_machine" "esxi_multiple_vswitch_wo_NSX_wo_Avi" {
  depends_on = [ vsphere_file.iso_upload ]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create == false ? var.esxi.count : 0)
  name             = "${var.esxi.basename}${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

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
      label = "${var.esxi.basename}${count.index + 1}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "vsphere_virtual_machine" "esxi_multiple_vswitch_wo_NSX_with_Avi" {
  depends_on = [ vsphere_file.iso_upload ]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == false && var.avi.create == true ? var.esxi.count : 0)
  name             = "${var.esxi.basename}${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

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

  network_interface {
    network_id = data.vsphere_network.network_avi_mgmt[0].id
  }

  network_interface {
    network_id = data.vsphere_network.network_avi_vip[0].id
  }

  network_interface {
    network_id = data.vsphere_network.network_avi_backend[0].id
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
      label = "${var.esxi.basename}${count.index + 1}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "vsphere_virtual_machine" "esxi_multiple_vswitch_with_NSX_with_Avi" {
  depends_on = [ vsphere_file.iso_upload ]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.create == true && var.avi.create == true ? var.esxi.count : 0)
  name             = "${var.esxi.basename}${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

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
      label = "${var.esxi.basename}${count.index + 1}-${disk.value["label"]}.lab_vmdk"
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
  count = (var.vcenter.dvs.single_vds == true ? var.esxi.count : 0)
  name             = "${var.esxi.basename}${count.index + 1}"
  datastore_id     = data.vsphere_datastore.datastore.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  folder           = "/${var.vcenter_underlay.dc}/vm/${var.vcenter_underlay.folder}"

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
      label = "${var.esxi.basename}${count.index + 1}-${disk.value["label"]}.lab_vmdk"
      unit_number = disk.value["unit_number"]
      thin_provisioned = disk.value["thin_provisioned"]
    }
  }

  cdrom {
    datastore_id = data.vsphere_datastore.datastore.id
    path         = "isos/${basename(var.esxi.iso_location)}${count.index}.iso"
  }
}

resource "null_resource" "wait_esxi" {
  depends_on = [vsphere_virtual_machine.esxi_multiple_vswitch_with_NSX_with_Avi, vsphere_virtual_machine.esxi_multiple_vswitch_wo_NSX_with_Avi, vsphere_virtual_machine.esxi_multiple_vswitch_wo_NSX_wo_Avi, vsphere_virtual_machine.esxi_single_vswitch]
  count = var.esxi.count

  provisioner "local-exec" {
    command = "count=1 ; until $(curl --output /dev/null --silent --head -k https://${var.vcenter.dvs.portgroup.management.esxi_ips[count.index]}); do echo \"Attempt $count: Waiting for ESXi host ${count.index} to be reachable...\"; sleep 40 ; count=$((count+1)) ;  if [ \"$count\" = 30 ]; then echo \"ERROR: Unable to connect to ESXi host\" ; exit 1 ; fi ; done"
  }
}

resource "null_resource" "esxi_customization" {
  depends_on = [null_resource.wait_esxi]

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