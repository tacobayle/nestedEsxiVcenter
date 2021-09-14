resource "vsphere_content_library" "nested_library_ubuntu" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name            = "ubuntu-ssh-gw"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
}

resource "vsphere_content_library_item" "nested_library_item_ubuntu" {
  count = (var.ssh_gw.create == true ? 1 : 0)
  name        = basename(var.ssh_gw.ova_location)
  library_id  = vsphere_content_library.nested_library_ubuntu[0].id
  file_url = var.ssh_gw.ova_location
}
