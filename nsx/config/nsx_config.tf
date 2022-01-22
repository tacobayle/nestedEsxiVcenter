resource "null_resource" "waiting_for_nsx_api" {
  provisioner "local-exec" {
    command = "/bin/bash bash/waiting_for_nsx_api.sh"
  }
}

resource "null_resource" "ansible_init_manager" {
  depends_on = [null_resource.waiting_for_nsx_api]

  provisioner "local-exec" {
    command = "ansible-playbook ansible/ansible_init_manager.yml -e @../../variables.json"
  }
}

resource "null_resource" "register_compute_manager" {
  depends_on = [null_resource.ansible_init_manager]
  provisioner "local-exec" {
    command = "/bin/bash bash/register_compute_manager.sh"
  }
}

resource "nsxt_policy_ip_pool" "pools" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.ip_pools)
  display_name = var.nsx.config.ip_pools[count.index].name
}

resource "nsxt_policy_ip_pool_static_subnet" "static_subnet" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.ip_pools)
  display_name = "${var.nsx.config.ip_pools[count.index].name}-static-subnet"
  pool_path    = nsxt_policy_ip_pool.pools[count.index].path
  cidr         = var.nsx.config.ip_pools[count.index].cidr
  gateway      = var.nsx.config.ip_pools[count.index].gateway

  allocation_range {
    start = var.nsx.config.ip_pools[count.index].start
    end   = var.nsx.config.ip_pools[count.index].end
  }

}

data "nsxt_policy_transport_zone" "vlan_transport_zone" {
  depends_on = [null_resource.register_compute_manager]
  count = length(var.nsx.config.segments)
  display_name        = var.nsx.config.segments[count.index].transport_zone
}


resource "nsxt_policy_segment" "segments_for_single_vds" {
  depends_on = [null_resource.register_compute_manager]
  count = (var.vcenter.dvs.single_vds == true && var.nsx.config.create == true ? length(var.nsx.config.segments) : 0)
  display_name        = var.nsx.config.segments[count.index].name
  vlan_ids = [var.nsx.config.segments[count.index].vlan]
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_transport_zone[count.index].path
  description         = var.nsx.config.segments[count.index].description
}

resource "nsxt_policy_segment" "segments_for_multiple_vds" {
  depends_on = [null_resource.register_compute_manager]
  count = (var.vcenter.dvs.single_vds == false && var.nsx.config.create == true ? length(var.nsx.config.segments) : 0)
  display_name        = var.nsx.config.segments[count.index].name
  vlan_ids = ["0"]
  transport_zone_path = data.nsxt_policy_transport_zone.vlan_transport_zone[count.index].path
  description         = var.nsx.config.segments[count.index].description
}

resource "null_resource" "create_transport_node_profiles" {
  depends_on = [nsxt_policy_ip_pool.pools, nsxt_policy_ip_pool_static_subnet.static_subnet, nsxt_policy_segment.segments_for_single_vds, nsxt_policy_segment.segments_for_multiple_vds]
  provisioner "local-exec" {
    command = "ansible-playbook ansible/create_transport_node_profiles.yml -e @../../variables.json"
  }
}

resource "null_resource" "create_host_transport_node" {
  depends_on = [null_resource.create_transport_node_profiles]
  provisioner "local-exec" {
    command = "/bin/bash bash/create_host_transport_node.sh"
  }
}