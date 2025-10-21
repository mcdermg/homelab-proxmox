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
    node     = "pve01"
    insecure = true
    ssh_user = "root"
  }
}

variable "proxmox_auth" {
  description = "Proxmox authentication credentials"
  type = object({
    api_token    = optional(string, "")
    username     = optional(string, "")
    password     = optional(string, "")
    ssh_password = optional(string, "")
  })
  sensitive = true
}

# DOWNLOADS
## ISO DOWNLOADS
variable "iso_downloads" {
  description = "ISO files to download to Proxmox storage"
  type = map(object({
    url                     = string
    file_name               = optional(string)
    checksum                = optional(string)
    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"
    decompression_algorithm = optional(string)
    verify                  = optional(bool, true)
    overwrite               = optional(bool, true)
    overwrite_unmanaged     = optional(bool, false)
    upload_timeout          = optional(number, 1800)
  }))
  default = {
    debian_13_1 = {
      url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
    }
    alpine_322 = {
      url = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-standard-3.22.2-x86_64.iso"
    }
    ubuntu_2404 = {
      url = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
    }
  }
}

## LXC CONTAINER TEMPLATE DOWNLOADS
variable "lxc_template_downloads" {
  description = "LXC container templates to download to Proxmox storage"
  type = map(object({
    url                     = string
    file_name               = optional(string)
    checksum                = optional(string)
    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"
    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"
    verify                  = optional(bool, true)
    overwrite               = optional(bool, true)
    overwrite_unmanaged     = optional(bool, false)
    upload_timeout          = optional(number, 1800)
  }))
  default = {
    alpine_322 = {
      url = "http://download.proxmox.com/images/system/alpine-3.22-default_20250617_amd64.tar.xz"
    }
    debian_13 = {
      url = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
    }
    turnkey_debian_12_gitea = {
      url = "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-gitea_18.0-1_amd64.tar.gz"
    }
    turnkey_debian_11_postgresql = {
      url = "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-11-turnkey-postgresql_17.1-1_amd64.tar.gz"
    }
    turnkey_debian_11_redis = {
      url = "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-11-turnkey-redis_17.1-1_amd64.tar.gz"
    }
  }
}

## VM IMAGE DOWNLOADS
variable "vm_image_downloads" {
  description = "VM disk images to download to Proxmox storage"
  type = map(object({
    url                     = string
    file_name               = optional(string)
    checksum                = optional(string)
    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"
    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"
    verify                  = optional(bool, true)
    overwrite               = optional(bool, true)
    overwrite_unmanaged     = optional(bool, false)
    upload_timeout          = optional(number, 1800)
  }))
  default = {
    #ubuntu_2404_cloud = {
    #  url                = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
    #  file_name          = "ubuntu-24.04-cloudimg-amd64.img"
    #  checksum           = "d2377667ea95222330ca2287817403c85178dd7e5967a071b83a75ef8c28105f"
    #  checksum_algorithm = "sha256"
    #}
    # debian_12_cloud = {
    #   url       = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    #   file_name = "debian-12-generic-amd64.img"
    # }
  }
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
      enabled = false
      timeout = "4m"
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
    ssh_public_key = optional(string, "")
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
      name       = "k3s-control-tf-01"
      cores      = 2
      memory     = 4096
      ip_address = "192.168.1.210"
      role       = "control"
    }
    control_02 = {
      vm_id      = 211
      name       = "k3s-control-tf-02"
      cores      = 2
      memory     = 4096
      ip_address = "192.168.1.211"
      role       = "control"
    }
    worker_01 = {
      vm_id      = 215
      name       = "k3s-node-tf-01"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.215"
      role       = "node"
    }
    worker_02 = {
      vm_id      = 216
      name       = "k3s-node-tf-02"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.216"
      role       = "node"
    }
    worker_03 = {
      vm_id      = 217
      name       = "k3s-node-tf-03"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.217"
      role       = "node"
    }
  }
}
