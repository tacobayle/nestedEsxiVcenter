resource "nsxt_policy_ip_pool" "pools" {
  depends_on = [null_resource.ansible_init_manager]
  count = length(var.nsx.config.ip_pools)
  display_name = var.nsx.config.ip_pools[count.index].name
}

resource "nsxt_policy_ip_pool_static_subnet" "static_subnet" {
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