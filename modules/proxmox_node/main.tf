# APT REPOSITORIES
resource "proxmox_apt_standard_repository" "enabled" {
  for_each = toset(var.apt_repositories.enabled)

  node   = var.node_name
  handle = each.key
}

resource "proxmox_apt_repository" "enabled" {
  for_each = toset(var.apt_repositories.enabled)

  node      = var.node_name
  file_path = proxmox_apt_standard_repository.enabled[each.key].file_path
  index     = proxmox_apt_standard_repository.enabled[each.key].index
  enabled   = true
}

resource "proxmox_apt_repository" "disabled" {
  for_each = data.proxmox_apt_standard_repository.disabled

  node      = each.value.node
  file_path = each.value.file_path
  index     = each.value.index
  enabled   = false
}

# ZFS POOL
# The storage entry is cluster-wide and managed in the root module, so add_storage stays off
resource "proxmox_node_disk_zfs" "this" {
  node_name   = var.node_name
  name        = var.zfs_pool_name
  devices     = var.zfs_pool.devices
  raidlevel   = var.zfs_pool.raidlevel
  add_storage = false
}
