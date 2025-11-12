# Terraform Proxmox K3s Cluster

Terraform configuration for provisioning virtual machines on Proxmox VE to host a K3s Kubernetes cluster. This repository manages VM infrastructure, while K3s installation is handled by Ansible.

## Overview

This project creates and manages VMs for a **K3s High Availability cluster** with embedded etcd:

**Terraform-managed VMs:**
- 2 K3s control plane VMs (2 cores, 4GB RAM each)
- 2 K3s worker VMs (2 cores, 2GB RAM each)

**Additional nodes (managed via Ansible):**
- 1 Raspberry Pi 4 control plane node (for HA quorum - 3 nodes required)
- 1 Raspberry Pi 3 worker node

**Total cluster:** 3 control plane nodes + 3 worker nodes (HA configuration)

All VMs use IP addresses that match their VM IDs in the last octet (e.g., VM 210 → 192.168.1.210).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.13 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.85 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.12.0 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.5.3 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_iso_downloads"></a> [iso\_downloads](#module\_iso\_downloads) | ./modules/download_file | n/a |
| <a name="module_k3s_cluster"></a> [k3s\_cluster](#module\_k3s\_cluster) | ./modules/k3s_cluster | n/a |
| <a name="module_lxc_containers"></a> [lxc\_containers](#module\_lxc\_containers) | ./modules/lxc_container | n/a |
| <a name="module_lxc_template_downloads"></a> [lxc\_template\_downloads](#module\_lxc\_template\_downloads) | ./modules/download_file | n/a |
| <a name="module_tunnel_dns_records"></a> [tunnel\_dns\_records](#module\_tunnel\_dns\_records) | ./modules/cloudflare_dns | n/a |
| <a name="module_vm_image_downloads"></a> [vm\_image\_downloads](#module\_vm\_image\_downloads) | ./modules/download_file | n/a |

## Resources

| Name | Type |
|------|------|
| [cloudflare_zero_trust_tunnel_cloudflared.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [local_file.ansible_hosts_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [random_id.cloudflared_tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare Account ID for tunnel management | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for managing DNS and tunnels | `string` | n/a | yes |
| <a name="input_cloudflare_zone"></a> [cloudflare\_zone](#input\_cloudflare\_zone) | Cloudflare zone/domain name | `string` | n/a | yes |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare Zone ID for the domain | `string` | n/a | yes |
| <a name="input_iso_downloads"></a> [iso\_downloads](#input\_iso\_downloads) | ISO files to download to Proxmox storage | <pre>map(object({<br>    url                     = string<br>    file_name               = optional(string)<br>    checksum                = optional(string)<br>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br>    decompression_algorithm = optional(string)<br>    verify                  = optional(bool, true)<br>    overwrite               = optional(bool, true)<br>    overwrite_unmanaged     = optional(bool, false)<br>    upload_timeout          = optional(number, 1800)<br>  }))</pre> | <pre>{<br>  "alpine_322": {<br>    "url": "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-standard-3.22.2-x86_64.iso"<br>  },<br>  "debian_13_1": {<br>    "url": "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"<br>  },<br>  "ubuntu_2404": {<br>    "url": "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"<br>  }<br>}</pre> | no |
| <a name="input_k3s_defaults"></a> [k3s\_defaults](#input\_k3s\_defaults) | Default configuration for K3s VMs | <pre>object({<br>    disk_interface = string<br>    disk_size      = number<br>    qemu_agent = object({<br>      enabled = bool<br>      timeout = string<br>    })<br>    behavior = object({<br>      on_boot         = bool<br>      started         = bool<br>      stop_on_destroy = bool<br>    })<br>  })</pre> | <pre>{<br>  "behavior": {<br>    "on_boot": true,<br>    "started": true,<br>    "stop_on_destroy": true<br>  },<br>  "disk_interface": "scsi0",<br>  "disk_size": 17,<br>  "qemu_agent": {<br>    "enabled": false,<br>    "timeout": "4m"<br>  }<br>}</pre> | no |
| <a name="input_k3s_template_vm_id"></a> [k3s\_template\_vm\_id](#input\_k3s\_template\_vm\_id) | VM ID of the template to clone for K3s nodes | `number` | `9000` | no |
| <a name="input_k3s_vms"></a> [k3s\_vms](#input\_k3s\_vms) | K3s cluster VM specifications | <pre>map(object({<br>    vm_id      = number<br>    name       = string<br>    cores      = number<br>    memory     = number<br>    ip_address = string<br>    role       = string<br>  }))</pre> | <pre>{<br>  "control_01": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.210",<br>    "memory": 2048,<br>    "name": "k3s-control-tf-01",<br>    "role": "control",<br>    "vm_id": 210<br>  },<br>  "control_02": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.211",<br>    "memory": 2048,<br>    "name": "k3s-control-tf-02",<br>    "role": "control",<br>    "vm_id": 211<br>  },<br>  "worker_01": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.215",<br>    "memory": 2048,<br>    "name": "k3s-node-tf-01",<br>    "role": "node",<br>    "vm_id": 215<br>  },<br>  "worker_02": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.216",<br>    "memory": 2048,<br>    "name": "k3s-node-tf-02",<br>    "role": "node",<br>    "vm_id": 216<br>  }<br>}</pre> | no |
| <a name="input_lxc_containers"></a> [lxc\_containers](#input\_lxc\_containers) | LXC container specifications | <pre>map(object({<br>    vm_id            = number<br>    name             = string<br>    template_file_id = string<br>    os_type          = optional(string, "debian")<br><br>    # Resources<br>    cores     = optional(number, 1)<br>    cpu_units = optional(number, 1024)<br>    memory    = optional(number, 512)<br>    swap      = optional(number, 0)<br>    disk_size = optional(number, 8)<br><br>    # Network<br>    ip_address = string # Main IP address for the container<br><br>    # Optional advanced configuration<br>    description  = optional(string)<br>    unprivileged = optional(bool, true)<br><br>    # Features for special use cases<br>    features = optional(object({<br>      nesting = optional(bool, false) # Enable for Docker/nested containers<br>      keyctl  = optional(bool, false) # Enable for systemd<br>      fuse    = optional(bool, false)<br>      mount   = optional(list(string), [])<br>    }))<br><br>    # Startup configuration<br>    startup_order = optional(number)<br>    start_on_boot = optional(bool, true)<br>    started       = optional(bool, true)<br><br>    # Tags (terraform and IP will be auto-added)<br>    tags = optional(list(string), [])<br>  }))</pre> | <pre>{<br>  "bind9": {<br>    "cores": 2,<br>    "disk_size": 10,<br>    "features": {<br>      "nesting": true<br>    },<br>    "ip_address": "192.168.1.115",<br>    "memory": 2048,<br>    "name": "bind9",<br>    "os_type": "debian",<br>    "started": false,<br>    "swap": 512,<br>    "tags": [<br>      "turnkey"<br>    ],<br>    "template_file_id": "debian-12-turnkey-core_18.0-1_amd64.tar.gz",<br>    "vm_id": 115<br>  },<br>  "caddy": {<br>    "cores": 1,<br>    "disk_size": 8,<br>    "features": {<br>      "nesting": false<br>    },<br>    "ip_address": "192.168.1.114",<br>    "memory": 1024,<br>    "name": "caddy",<br>    "os_type": "alpine",<br>    "started": false,<br>    "swap": 256,<br>    "tags": [<br>      "alpine"<br>    ],<br>    "template_file_id": "alpine-3.22-default_20250617_amd64.tar.xz",<br>    "vm_id": 114<br>  },<br>  "cloudflared": {<br>    "cores": 1,<br>    "disk_size": 4,<br>    "features": {<br>      "nesting": false<br>    },<br>    "ip_address": "192.168.1.113",<br>    "memory": 512,<br>    "name": "cloudflared",<br>    "os_type": "alpine",<br>    "started": false,<br>    "swap": 128,<br>    "tags": [<br>      "alpine"<br>    ],<br>    "template_file_id": "alpine-3.22-default_20250617_amd64.tar.xz",<br>    "vm_id": 113<br>  },<br>  "gitea": {<br>    "cores": 2,<br>    "disk_size": 10,<br>    "features": {<br>      "nesting": true<br>    },<br>    "ip_address": "192.168.1.117",<br>    "memory": 2048,<br>    "name": "gitea",<br>    "os_type": "debian",<br>    "started": false,<br>    "swap": 512,<br>    "tags": [<br>      "turnkey"<br>    ],<br>    "template_file_id": "debian-12-turnkey-gitea_18.0-1_amd64.tar.gz",<br>    "vm_id": 117<br>  },<br>  "postgres": {<br>    "cores": 2,<br>    "disk_size": 10,<br>    "features": {<br>      "nesting": true<br>    },<br>    "ip_address": "192.168.1.116",<br>    "memory": 2048,<br>    "name": "postgres",<br>    "os_type": "debian",<br>    "started": false,<br>    "swap": 512,<br>    "tags": [<br>      "turnkey"<br>    ],<br>    "template_file_id": "debian-11-turnkey-postgresql_17.1-1_amd64.tar.gz",<br>    "vm_id": 116<br>  }<br>}</pre> | no |
| <a name="input_lxc_defaults"></a> [lxc\_defaults](#input\_lxc\_defaults) | Default configuration for LXC containers | <pre>object({<br>    password       = string<br>    ssh_public_key = optional(string, "")<br>  })</pre> | n/a | yes |
| <a name="input_lxc_template_downloads"></a> [lxc\_template\_downloads](#input\_lxc\_template\_downloads) | LXC container templates to download to Proxmox storage | <pre>map(object({<br>    url                     = string<br>    file_name               = optional(string)<br>    checksum                = optional(string)<br>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br>    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"<br>    verify                  = optional(bool, true)<br>    overwrite               = optional(bool, true)<br>    overwrite_unmanaged     = optional(bool, false)<br>    upload_timeout          = optional(number, 1800)<br>  }))</pre> | <pre>{<br>  "alpine_322": {<br>    "url": "http://download.proxmox.com/images/system/alpine-3.22-default_20250617_amd64.tar.xz"<br>  },<br>  "debian_13": {<br>    "url": "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"<br>  },<br>  "turnkey_debian_11_postgresql": {<br>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-11-turnkey-postgresql_17.1-1_amd64.tar.gz"<br>  },<br>  "turnkey_debian_11_redis": {<br>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-11-turnkey-redis_17.1-1_amd64.tar.gz"<br>  },<br>  "turnkey_debian_12_core": {<br>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-core_18.0-1_amd64.tar.gz"<br>  },<br>  "turnkey_debian_12_gitea": {<br>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-gitea_18.0-1_amd64.tar.gz"<br>  }<br>}</pre> | no |
| <a name="input_network"></a> [network](#input\_network) | Network configuration for VMs | <pre>object({<br>    gateway     = string<br>    cidr_suffix = string<br>  })</pre> | <pre>{<br>  "cidr_suffix": "/24",<br>  "gateway": "192.168.1.1"<br>}</pre> | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Network bridge to use for VMs | `string` | `"vmbr0"` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | Name of the Proxmox node to use | `string` | `"pve01"` | no |
| <a name="input_proxmox"></a> [proxmox](#input\_proxmox) | Proxmox connection configuration | <pre>object({<br>    endpoint = string<br>    node     = string<br>    insecure = bool<br>    ssh_user = string<br>    ssh_port = optional(number, 22)<br>  })</pre> | n/a | yes |
| <a name="input_proxmox_auth"></a> [proxmox\_auth](#input\_proxmox\_auth) | Proxmox authentication credentials | <pre>object({<br>    api_token    = optional(string, "")<br>    username     = optional(string, "")<br>    password     = optional(string, "")<br>    ssh_password = optional(string, "")<br>  })</pre> | n/a | yes |
| <a name="input_vm_cloudinit"></a> [vm\_cloudinit](#input\_vm\_cloudinit) | Cloud-init configuration for VMs | <pre>object({<br>    username       = string<br>    password       = string<br>    ssh_public_key = optional(string, "")<br>  })</pre> | n/a | yes |
| <a name="input_vm_image_downloads"></a> [vm\_image\_downloads](#input\_vm\_image\_downloads) | VM disk images to download to Proxmox storage | <pre>map(object({<br>    url                     = string<br>    file_name               = optional(string)<br>    checksum                = optional(string)<br>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br>    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"<br>    verify                  = optional(bool, true)<br>    overwrite               = optional(bool, true)<br>    overwrite_unmanaged     = optional(bool, false)<br>    upload_timeout          = optional(number, 1800)<br>  }))</pre> | `{}` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
