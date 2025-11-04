resource "proxmox_virtual_environment_download_file" "this" {
  for_each = var.downloads

  node_name    = var.node_name
  datastore_id = var.datastore_id
  content_type = var.content_type

  url       = each.value.url
  file_name = each.value.file_name

  checksum           = each.value.checksum
  checksum_algorithm = each.value.checksum != null ? each.value.checksum_algorithm : null

  decompression_algorithm = each.value.decompression_algorithm

  verify              = each.value.verify
  overwrite           = each.value.overwrite
  overwrite_unmanaged = each.value.overwrite_unmanaged
  upload_timeout      = each.value.upload_timeout
}
