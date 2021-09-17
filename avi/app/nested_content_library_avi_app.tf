resource "vsphere_content_library" "nested_library_avi_app" {
  count = (var.avi.app.create == true ? 1 : 0)
  name            = "avi_app"
  storage_backing = [data.vsphere_datastore.datastore_nested[0].id]
}

resource "vsphere_content_library_item" "nested_library_item_avi_app" {
  count = (var.avi.app.create == true ? 1 : 0)
  name        = basename(var.avi.app.ova_location)
  library_id  = vsphere_content_library.nested_library_avi_app[0].id
  file_url = var.avi.app.ova_location
}
