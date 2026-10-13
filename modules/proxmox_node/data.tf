# Repos to disable ship with a fresh install, so they are looked up rather than added
data "proxmox_apt_standard_repository" "disabled" {
  for_each = toset(var.apt_repositories.disabled)

  node   = var.node_name
  handle = each.key
}
