resource "nsxt_policy_ip_pool" "pools" {
  count = length(var.nsx.ip_pools)
  display_name = var.nsx.ip_pools[count.index].name
}

resource "nsxt_policy_ip_pool_static_subnet" "static_subnet" {
  count = length(var.nsx.ip_pools)
  display_name = "${var.nsx.ip_pools[count.index].name}-static-subnet"
  pool_path    = nsxt_policy_ip_pool.pools[count.index].path
  cidr         = var.nsx.ip_pools[count.index].cidr
  gateway      = var.nsx.ip_pools[count.index].gateway

  allocation_range {
    start = var.nsx.ip_pools[count.index].start
    end   = var.nsx.ip_pools[count.index].end
  }

}