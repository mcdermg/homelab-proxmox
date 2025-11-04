variable "proxmox_node" {
  description = "The name of the Proxmox node where containers will be created"
  type        = string
}

variable "storage_pool" {
  description = "The storage pool for container disks"
  type        = string
}

variable "network_bridge" {
  description = "Default network bridge for containers"
  type        = string
  default     = "vmbr0"
}

variable "network_gateway" {
  description = "Default network gateway for containers"
  type        = string
  default     = null
}

variable "default_ssh_keys" {
  description = "Default SSH public keys for container root user"
  type        = list(string)
  default     = []
}

variable "default_password" {
  description = "Default password for container root user"
  type        = string
  sensitive   = true
  default     = null
}

variable "containers" {
  description = "LXC container specifications"
  type = map(object({
    vm_id            = number
    name             = string
    template_file_id = string # e.g., "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"

    # Optional configuration
    description  = optional(string)
    template     = optional(bool, false)
    unprivileged = optional(bool, true)
    os_type      = optional(string, "debian") # "alpine", "archlinux", "centos", "debian", "fedora", "gentoo", "opensuse", "ubuntu", "unmanaged"

    # Resources
    cores     = optional(number, 1)
    cpu_units = optional(number, 1024)
    memory    = optional(number, 512)
    swap      = optional(number, 0)
    disk_size = optional(number, 8)

    # Network configuration
    network_interfaces = optional(list(object({
      name        = string
      bridge      = optional(string)
      enabled     = optional(bool, true)
      firewall    = optional(bool, false)
      mac_address = optional(string)
      rate_limit  = optional(number)
      vlan_id     = optional(number)
    })), [])

    # IP configuration
    ip_configs = optional(list(object({
      ipv4_address = optional(string) # e.g., "192.168.1.100/24"
      ipv4_gateway = optional(string)
      ipv6_address = optional(string)
      ipv6_gateway = optional(string)
    })), [])

    # Authentication
    ssh_keys = optional(list(string))
    password = optional(string)

    # Features
    features = optional(object({
      fuse    = optional(bool, false)
      keyctl  = optional(bool, false)
      nesting = optional(bool, false)
      mount   = optional(list(string), [])
    }))

    # Console
    console = optional(object({
      enabled   = optional(bool, true)
      tty_count = optional(number, 2)
      type      = optional(string, "tty")
    }))

    # Startup configuration
    startup_order      = optional(number)
    startup_up_delay   = optional(number)
    startup_down_delay = optional(number)

    # Behavior
    start_on_boot = optional(bool, true)
    started       = optional(bool, true)
    protection    = optional(bool, false)

    # Tags
    tags = optional(list(string), [])
  }))
  default = {}
}
