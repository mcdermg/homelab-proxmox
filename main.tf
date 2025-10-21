locals {
  datastore_id = "usbstorage"
  node_name    = "pve01"
}

# DOWNLOADS
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

# K3S CLUSTER
module "k3s_cluster" {
  source = "./modules/k3s_cluster"

  cluster_nodes = var.k3s_vms

  # Proxmox settings
  proxmox_node   = var.proxmox.node
  template_vm_id = var.proxmox_infrastructure.template_vm_id
  storage_pool   = var.proxmox_infrastructure.storage_pool

  # Network config
  network_bridge      = var.proxmox_infrastructure.network_bridge
  network_gateway     = var.network.gateway
  network_cidr_suffix = var.network.cidr_suffix

  # VM defaults
  default_disk_interface = var.vm_defaults.disk_interface
  default_disk_size      = var.vm_defaults.disk_size
  qemu_agent_enabled     = var.vm_defaults.qemu_agent.enabled
  qemu_agent_timeout     = var.vm_defaults.qemu_agent.timeout
  vm_on_boot             = var.vm_defaults.behavior.on_boot
  vm_started             = var.vm_defaults.behavior.started
  vm_stop_on_destroy     = var.vm_defaults.behavior.stop_on_destroy

  # Cloud-init configuration
  cloudinit_username = var.vm_cloudinit.username
  cloudinit_password = var.vm_cloudinit.password
  cloudinit_ssh_key  = var.vm_cloudinit.ssh_public_key
}
