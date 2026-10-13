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
