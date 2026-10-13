variable "node_name" {
  description = "The name of the Proxmox node to configure"
  type        = string
}

variable "apt_repositories" {
  description = "APT standard repository handles to enable or disable on the node"
  type = object({
    enabled  = list(string)
    disabled = list(string)
  })
}

variable "zfs_pool_name" {
  description = "Name of the node's ZFS pool, the same on every node so one storage entry covers them all"
  type        = string
}

variable "zfs_pool" {
  description = "Disks and RAID level for the node's ZFS pool"
  type = object({
    devices   = list(string)
    raidlevel = string
  })
}
