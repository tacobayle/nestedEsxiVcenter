resource "vsphere_content_library" "nested_library_ssh_gw" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name            = "ssh-gw"
  storage_backing = [data.vsphere_datastore.datastore_nested[0].id]
}

resource "vsphere_content_library_item" "nested_library_item_ssh_gw" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name        = basename(var.ssh_gw.ova_location)
  library_id  = vsphere_content_library.nested_library_ssh_gw[0].id
  file_url = var.ssh_gw.ova_location
}
