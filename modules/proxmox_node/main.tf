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
