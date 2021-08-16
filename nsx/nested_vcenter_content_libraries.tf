resource "vsphere_content_library" "libraryNSX" {
  count = (var.nsx.create == true ? 1 : 0)
  provider        = vsphere.overlay
  name            = "NSX Library"
  storage_backing = [data.vsphere_datastore.datastore_nested.id]
}

resource "vsphere_content_library_item" "OvaNSX" {
  count = (var.nsx.create == true ? 1 : 0)
  provider        = vsphere.overlay
  name            = basename(var.nsx.ova_location)
  library_id      = vsphere_content_library.libraryNSX[0].id
  file_url        = var.nsx.ova_location
}