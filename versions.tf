terraform {
  required_version = "~> 1.13"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.85"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox.endpoint
  insecure = var.proxmox.insecure

  # PRIMARY: API Token Authentication (recommended)
  api_token = var.proxmox_auth.api_token

  # ALTERNATIVE: Username/Password Authentication (comment out api_token above and uncomment below)
  # username = var.proxmox_auth.username
  # password = var.proxmox_auth.password

  # SSH connection for certain operations (file uploads, etc.)
  ssh {
    agent    = true
    username = var.proxmox.ssh_user
    # Optional: Uncomment if not using SSH agent
    # password = var.proxmox_auth.ssh_password
  }
}

