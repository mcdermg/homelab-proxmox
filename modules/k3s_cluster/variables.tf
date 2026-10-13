# CLUSTER DEFINITION
variable "cluster_nodes" {
  description = "K3s cluster node specifications"
  type = map(object({
    vm_id      = number
    name       = string
    cores      = number
    memory     = number
    ip_address = string
    role       = string # "control" or "worker"
  }))
}

# PROXMOX CONFIGURATION
variable "proxmox_node" {
  description = "The Proxmox node where VMs will be created"
  type        = string
}

variable "storage_pool" {
  description = "The storage pool for VM disks and cloud-init"
  type        = string
}

# TEMPLATE CONFIGURATION
variable "template_storage_pool" {
  description = "The storage pool for the template's disk and cloud-init drive"
  type        = string
}

variable "templates" {
  description = "Templates to build, keyed by Proxmox node: VM ID and the cloud image file ID on that node (e.g. 'nvme-files:import/image.qcow2')"
  type = map(object({
    vm_id         = number
    image_file_id = string
  }))
}

variable "template_cores" {
  description = "CPU cores for the template"
  type        = number
  default     = 2
}

variable "template_memory" {
  description = "Memory in MB for the template"
  type        = number
  default     = 2048
}

variable "network_bridge" {
  description = "The network bridge for VM network devices"
  type        = string
}

# NETWORK CONFIGURATION
variable "network_gateway" {
  description = "The network gateway for VMs"
  type        = string
}

variable "network_cidr_suffix" {
  description = "CIDR suffix for IP addresses (e.g., '/24')"
  type        = string
}

# VM DEFAULTS
variable "default_disk_interface" {
  description = "Default disk interface (e.g., 'scsi0')"
  type        = string
  default     = "scsi0"
}

variable "default_disk_size" {
  description = "Default disk size in GB"
  type        = number
  default     = 17
}

variable "qemu_agent_enabled" {
  description = "Enable QEMU guest agent"
  type        = bool
  default     = false
}

variable "qemu_agent_timeout" {
  description = "QEMU agent timeout"
  type        = string
  default     = "4m"
}

variable "vm_on_boot" {
  description = "Start VM on boot"
  type        = bool
  default     = true
}

variable "vm_started" {
  description = "Start VM after creation"
  type        = bool
  default     = true
}

variable "vm_stop_on_destroy" {
  description = "Stop VM when destroying"
  type        = bool
  default     = true
}

# CLOUD-INIT CONFIGURATION
variable "cloudinit_username" {
  description = "Cloud-init user account username"
  type        = string
}

variable "cloudinit_password" {
  description = "Cloud-init user account password"
  type        = string
  sensitive   = true
}

variable "cloudinit_ssh_key" {
  description = "SSH public key for cloud-init user"
  type        = string
  default     = ""
}
