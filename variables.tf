# PROXMOX CONNECTION
variable "proxmox" {
  description = "Proxmox connection configuration"
  type = object({
    endpoint = string
    node     = string
    insecure = bool
    ssh_user = string
    ssh_port = optional(number, 2222)
  })
}

variable "proxmox_nodes" {
  description = "Proxmox nodes: SSH address, the disks for each node's ZFS storage pool, and the VM ID of its k3s template"
  type = map(object({
    address        = string
    template_vm_id = number
    zfs_pool = object({
      devices   = list(string)
      raidlevel = optional(string, "single")
    })
  }))
  default = {
    pve01 = {
      address        = "192.168.1.250"
      template_vm_id = 9000
      zfs_pool = {
        devices = ["/dev/disk/by-id/nvme-CA3-8D512-Q11_NVMe_LITEON_512GB_TW092X04LOH009BQ0115"]
      }
    }
    pve02 = {
      address        = "192.168.1.251"
      template_vm_id = 9001
      zfs_pool = {
        devices = ["/dev/disk/by-id/nvme-Micron_2200S_NVMe_512GB__194725011C72"]
      }
    }
  }
}

variable "apt_repositories" {
  description = "APT standard repository handles to enable or disable on every Proxmox node"
  type = object({
    enabled  = list(string)
    disabled = list(string)
  })
  default = {
    enabled  = ["no-subscription"]
    disabled = ["enterprise", "ceph-squid-enterprise"]
  }
}

variable "proxmox_auth" {
  description = "Proxmox authentication credentials"
  type = object({
    api_token = string
  })
  sensitive = true

  validation {
    condition     = can(regex("^[^!]+![^=]+=.+$", var.proxmox_auth.api_token))
    error_message = "proxmox_auth.api_token must be in the form user@realm!tokenid=secret."
  }
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
  # Nothing uses these: VMs are cloned from the cloud image template and LXCs use templates.
  # They were only used for early install testing. Uncomment one if a manual install needs it.
  default = {
    # # Archive URL: debian-cd/current/ only holds the latest point release and 404s once it moves on
    # debian_13_6 = {
    #   url = "https://cdimage.debian.org/cdimage/archive/13.6.0/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso"
    # }
    # alpine_322 = {
    #   url = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-standard-3.22.2-x86_64.iso"
    # }
    # ubuntu_2404 = {
    #   url = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
    # }
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
    turnkey_debian_12_postgresql = {
      url = "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz"
    }
    turnkey_debian_12_core = {
      url = "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-core_18.1-1_amd64.tar.gz"
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
    # Pinned release so rebuilds get the same image
    # generic not genericcloud: the cloud kernel lacks the drivers to see the cloud-init drive on ide2
    debian_13_generic = {
      url                = "https://cloud.debian.org/images/cloud/trixie/20261001-2618/debian-13-generic-amd64-20261001-2618.qcow2"
      checksum           = "6f0f93335bdef4ccf523c4317cc663ea52ca23b862667785f3d6d186ab4674a937385ccff0c55996b4b2e4c19e440cdf211e2a75ffa2f6548037ab43950c841d"
      checksum_algorithm = "sha512"
    }
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

# SSH ACCESS
variable "ssh_public_key_file" {
  description = "Public key authorized on every k3s VM (cloud-init user) and LXC container (root), read from the machine running tofu"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# VM CLOUD-INIT CONFIGURATION
variable "vm_cloudinit" {
  description = "Cloud-init configuration for VMs"
  type = object({
    username = string
    password = string
  })
  sensitive = true
}

# LXC CONTAINER DEFAULTS
variable "lxc_defaults" {
  description = "Default configuration for LXC containers"
  type = object({
    password = string
  })
  sensitive = true
}

# APPLICATION CREDENTIALS
# These end up unescaped in shell, sed and SQL in the init scripts, so stick to letters, digits, '.', '_' and '-'
variable "gitea_db_password" {
  description = "Password for Gitea PostgreSQL database user"
  type        = string
  sensitive   = true
}

variable "gitea_admin_password" {
  description = "Password for Gitea admin user"
  type        = string
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "Password for the postgres superuser, set by TurnKey's first boot"
  type        = string
  sensitive   = true
}

variable "pulse_admin_password" {
  description = "Password for the Pulse web UI admin user"
  type        = string
  sensitive   = true
}

# K3S CLUSTER CONFIGURATION
variable "k3s_roles" {
  description = "k3s VM roles: VM ID range (VM ID = last IP octet) and default size"
  type = map(object({
    first_id = number
    last_id  = number
    cores    = number
    memory   = number
  }))
  default = {
    control = { first_id = 210, last_id = 214, cores = 2, memory = 2048 }
    worker  = { first_id = 215, last_id = 220, cores = 2, memory = 4096 }
  }
}

variable "k3s_vms" {
  description = "k3s VMs keyed <role>_<NN> (e.g. worker_03); VM ID, IP and name are derived from the key and k3s_roles"
  type = map(object({
    node_name = string
    cores     = optional(number) # defaults to the role's cores
    memory    = optional(number) # defaults to the role's memory
  }))
  default = {
    control_01 = { node_name = "pve01" }
    control_02 = { node_name = "pve02" } # control planes on different nodes
    worker_01  = { node_name = "pve01", memory = 2048 }
    worker_02  = { node_name = "pve01", memory = 2048 }
    worker_03  = { node_name = "pve02" }
    worker_04  = { node_name = "pve02" }
    worker_05  = { node_name = "pve02" }
    worker_06  = { node_name = "pve02" }
  }

  validation {
    condition = alltrue([
      for key in keys(var.k3s_vms) : try(
        can(regex("^[a-z]+_[0-9]{2}$", key)) &&
        tonumber(split("_", key)[1]) >= 1 &&
        var.k3s_roles[split("_", key)[0]].first_id + tonumber(split("_", key)[1]) - 1 <= var.k3s_roles[split("_", key)[0]].last_id,
        false
      )
    ])
    error_message = "k3s_vms keys must be <role>_<NN> (e.g. worker_03), with a role from k3s_roles and NN inside that role's ID range."
  }

  validation {
    condition     = alltrue([for vm in var.k3s_vms : contains(keys(var.proxmox_nodes), vm.node_name)])
    error_message = "Each k3s_vms node_name must be a key of var.proxmox_nodes."
  }
}

# K3S RASPBERRY PI NODES
variable "k3s_pi_01_ip" {
  description = "IP address for K3s Raspberry Pi control node 01"
  type        = string
}

variable "k3s_pi_02_ip" {
  description = "IP address for K3s Raspberry Pi worker node 01"
  type        = string
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

    # Placement and network
    # shortcut: the pct-based Ansible plays (postgres, gitea, bind9, cloudflared) only reach var.proxmox.node; bind9 and cloudflared are on pve02, so don't run their plays until the inventory is per-node (LAB-65)
    node_name  = optional(string) # defaults to var.proxmox.node
    ip_address = string           # Main IP address for the container

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
    # Plain Debian 13 containers, configured over SSH by Ansible (sizes follow the community-scripts helpers)
    librespeed = {
      vm_id            = 111
      name             = "librespeed"
      template_file_id = "debian-13-standard_13.1-2_amd64.tar.zst"
      os_type          = "debian"
      cores            = 1
      memory           = 512
      disk_size        = 4
      swap             = 256
      ip_address       = "192.168.1.111"
      features = {
        nesting = true
      }
      tags = ["debian"]
    }
    pulse = {
      vm_id            = 112
      name             = "pulse"
      template_file_id = "debian-13-standard_13.1-2_amd64.tar.zst"
      os_type          = "debian"
      cores            = 1
      memory           = 1024
      disk_size        = 8
      swap             = 256
      ip_address       = "192.168.1.112"
      features = {
        nesting = true
      }
      tags = ["debian", "monitoring"]
    }
    cloudflared = {
      vm_id            = 113
      name             = "cloudflared"
      template_file_id = "debian-12-turnkey-core_18.1-1_amd64.tar.gz"
      os_type          = "debian"
      cores            = 1
      memory           = 512
      disk_size        = 8
      swap             = 256
      node_name        = "pve02"
      ip_address       = "192.168.1.113"
      started          = false
      features = {
        nesting = true # systemd 252 in an unprivileged container needs it
      }
      tags = ["turnkey"]
    }
    caddy = {
      vm_id            = 114
      name             = "caddy"
      template_file_id = "alpine-3.22-default_20250617_amd64.tar.xz"
      os_type          = "alpine"
      cores            = 1
      memory           = 512
      disk_size        = 8
      swap             = 256
      node_name        = "pve02"
      ip_address       = "192.168.1.114"
      started          = false
      features = {
        nesting = false
      }
      tags = ["alpine"]
    }
    bind9 = {
      vm_id            = 115
      name             = "bind9"
      template_file_id = "debian-12-turnkey-core_18.1-1_amd64.tar.gz"
      os_type          = "debian"
      cores            = 2
      memory           = 512
      disk_size        = 10
      swap             = 512
      node_name        = "pve02"
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
      template_file_id = "debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz"
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

  validation {
    condition     = alltrue([for c in var.lxc_containers : c.node_name == null || contains(keys(var.proxmox_nodes), c.node_name)])
    error_message = "Each lxc_containers node_name must be a key of var.proxmox_nodes."
  }
}

# CLOUDFLARE CONFIGURATION
variable "cloudflare_api_token" {
  description = "Cloudflare API token for managing DNS and tunnels"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID for tunnel management"
  type        = string
}

variable "cloudflare_zone" {
  description = "Cloudflare zone/domain name"
  type        = string
}

# TODO is locals doing all this work? Should move to tfvars?
#variable "cloudflare_tunnel_services" {
#  description = "Map of services to expose via Cloudflare Tunnel"
#  type = map(object({
#    service = string # e.g., "http://192.168.1.100:8080"
#  }))
#  default = {}
#}


# TODO pulse. see tfvars file
