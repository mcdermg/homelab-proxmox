# PROXMOX CONNECTION
variable "proxmox" {
  description = "Proxmox connection configuration"
  type = object({
    endpoint = string
    node     = string
    insecure = bool
    ssh_user = string
  })
  default = {
    endpoint = "https://192.168.1.250:8006"
    node     = "msi-proxmox"
    insecure = true
    ssh_user = "root"
  }
}

variable "proxmox_auth" {
  description = "Proxmox authentication credentials"
  type = object({
    api_token    = string
    username     = string
    password     = string
    ssh_password = string
  })
  sensitive = true
}

# PROXMOX INFRASTRUCTURE
variable "proxmox_infrastructure" {
  description = "Proxmox infrastructure settings"
  type = object({
    storage_pool   = string
    network_bridge = string
    template_vm_id = number
  })
  default = {
    storage_pool   = "local-lvm"
    network_bridge = "vmbr0"
    template_vm_id = 9000
  }
}

# VM DEFAULTS
variable "vm_defaults" {
  description = "Default VM configuration"
  type = object({
    disk_interface = string
    disk_size      = number
    qemu_agent = object({
      enabled = bool
      timeout = string
    })
    behavior = object({
      on_boot         = bool
      started         = bool
      stop_on_destroy = bool
    })
  })
  default = {
    disk_interface = "scsi0"
    disk_size      = 17
    qemu_agent = {
      enabled = true
      timeout = "15m"
    }
    behavior = {
      on_boot         = true
      started         = true
      stop_on_destroy = true
    }
  }
}

# NETWORK CONFIGURATION
variable "network" {
  description = "Network configuration for VMs"
  type = object({
    gateway     = string
    cidr_suffix = string
  })
  default = {
    gateway     = "192.168.1.1"
    cidr_suffix = "/24"
  }
}

# VM CLOUD-INIT CONFIGURATION
variable "vm_cloudinit" {
  description = "Cloud-init configuration for VMs"
  type = object({
    username       = string
    password       = string
    ssh_public_key = string
  })
  sensitive = true
}

# K3S CLUSTER VM DEFINITIONS
variable "k3s_vms" {
  description = "K3s cluster VM specifications"
  type = map(object({
    vm_id      = number
    name       = string
    cores      = number
    memory     = number
    ip_address = string
    role       = string
  }))
  default = {
    control_01 = {
      vm_id      = 210
      name       = "k3s-main-tf-01"
      cores      = 2
      memory     = 4096
      ip_address = "192.168.1.100"
      role       = "control"
    }
    worker_01 = {
      vm_id      = 211
      name       = "k3s-worker-tf-01"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.101"
      role       = "worker"
    }
    worker_02 = {
      vm_id      = 212
      name       = "k3s-worker-tf-02"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.102"
      role       = "worker"
    }
    worker_03 = {
      vm_id      = 213
      name       = "k3s-worker-tf-03"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.103"
      role       = "worker"
    }
  }
}

# QEMU GUEST AGENT
variable "qemu_agent_enabled" {
  description = "Enable QEMU guest agent for VMs"
  type        = bool
  default     = true
}

variable "qemu_agent_timeout" {
  description = "Timeout for QEMU agent operations"
  type        = string
  default     = "15m"
}

# VM BEHAVIOR
variable "vm_on_boot" {
  description = "Start VMs automatically on Proxmox boot"
  type        = bool
  default     = true
}

variable "vm_started" {
  description = "VM power state after creation"
  type        = bool
  default     = true
}

variable "vm_stop_on_destroy" {
  description = "Stop VM before destroying (vs force shutdown)"
  type        = bool
  default     = true
}

