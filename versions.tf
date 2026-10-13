# OpenTofu ignores required_version, so the version is pinned here
language {
  compatible_with {
    opentofu = "~> 1.12"
  }
}

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.116"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.27"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox.endpoint
  insecure  = var.proxmox.insecure
  api_token = var.proxmox_auth.api_token

  # SSH connection for certain operations (file uploads, etc.)
  ssh {
    agent    = true
    username = var.proxmox.ssh_user

    # SSH port is only configurable per node
    dynamic "node" {
      for_each = var.proxmox_nodes
      content {
        name    = node.key
        address = node.value.address
        port    = var.proxmox.ssh_port
      }
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
