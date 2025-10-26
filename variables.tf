# PROXMOX CONNECTION
variable "proxmox" {
  description = "Proxmox connection configuration"
  type = object({
    endpoint = string
    node     = string
    insecure = bool
    ssh_user = string
  })
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

variable "node_name" {
  description = "Name of the Proxmox node to use"
  type        = string
  default     = "pve01"
}

variable "network_bridge" {
  description = "Network bridge to use for VMs"
  type        = string
  default     = "vmbr0"
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

# K3S VM DEFAULTS
variable "k3s_defaults" {
  description = "Default configuration for K3s VMs"
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

# LXC CONTAINER DEFAULTS
variable "lxc_defaults" {
  description = "Default configuration for LXC containers"
  type = object({
    password       = string
    ssh_public_key = optional(string, "")
  })
  sensitive = true
}

# K3S CLUSTER CONFIGURATION
variable "k3s_template_vm_id" {
  description = "VM ID of the template to clone for K3s nodes"
  type        = number
  default     = 9000
}

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

# LXC CONTAINER DEFINITIONS
variable "lxc_containers" {
  description = "LXC container specifications"
  type = map(object({
    vm_id            = number
    name             = string
    template_file_id = string
    os_type          = optional(string, "debian")

    # Resources
    cores     = optional(number, 1)
    cpu_units = optional(number, 1024)
    memory    = optional(number, 512)
    swap      = optional(number, 0)
    disk_size = optional(number, 8)

    # Network
    ip_address = string # Main IP address for the container

    # Optional advanced configuration
    description  = optional(string)
    unprivileged = optional(bool, true)

    # Features for special use cases
    features = optional(object({
      nesting = optional(bool, false) # Enable for Docker/nested containers
      keyctl  = optional(bool, false) # Enable for systemd
      fuse    = optional(bool, false)
      mount   = optional(list(string), [])
    }))

    # Startup configuration
    startup_order = optional(number)
    start_on_boot = optional(bool, true)
    started       = optional(bool, true)

    # Tags (terraform and IP will be auto-added)
    tags = optional(list(string), [])
  }))
  default = {
    alpine = {
      vm_id            = 113
      name             = "alpine"
      template_file_id = "alpine-3.22-default_20250617_amd64.tar.xz"
      os_type          = "alpine"
      cores            = 1
      memory           = 512
      disk_size        = 8
      ip_address       = "192.168.1.113"
      tags             = []
    }
    debian = {
      vm_id            = 114
      name             = "debian"
      template_file_id = "debian-13-standard_13.1-2_amd64.tar.zst"
      os_type          = "debian"
      cores            = 2
      memory           = 2048
      disk_size        = 20
      ip_address       = "192.168.1.114"
      tags             = []
    }
    redis = {
      vm_id            = 115
      name             = "redis"
      template_file_id = "debian-11-turnkey-redis_17.1-1_amd64.tar.gz"
      os_type          = "debian"
      cores            = 2
      memory           = 2048
      disk_size        = 10
      swap             = 512
      ip_address       = "192.168.1.115"
      started          = false
      features = {
        nesting = true
      }
      tags = ["turnkey"]
    }
    postgres = {
      vm_id            = 116
      name             = "postgres"
      template_file_id = "debian-11-turnkey-postgresql_17.1-1_amd64.tar.gz"
      os_type          = "debian"
      cores            = 2
      memory           = 2048
      disk_size        = 10
      swap             = 512
      ip_address       = "192.168.1.116"
      started          = false
      features = {
        nesting = true
      }
      tags = ["turnkey"]
    }
    gitea = {
      vm_id            = 117
      name             = "gitea"
      template_file_id = "debian-12-turnkey-gitea_18.0-1_amd64.tar.gz"
      os_type          = "debian"
      cores            = 2
      memory           = 2048
      disk_size        = 10
      swap             = 512
      ip_address       = "192.168.1.117"
      started          = false
      features = {
        nesting = true
      }
      tags = ["turnkey"]
    }
  }
}
