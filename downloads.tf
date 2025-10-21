module "iso_downloads" {
  source = "./modules/download_file"

  node_name    = local.node_name
  datastore_id = local.datastore_id
  downloads    = var.iso_downloads
  content_type = "iso"
}

module "lxc_template_downloads" {
  source = "./modules/download_file"

  node_name    = local.node_name
  datastore_id = local.datastore_id
  downloads    = var.lxc_template_downloads
  content_type = "vztmpl"
}

module "vm_image_downloads" {
  source = "./modules/download_file"

  node_name    = local.node_name
  datastore_id = local.datastore_id
  downloads    = var.vm_image_downloads
  content_type = "import"
}
