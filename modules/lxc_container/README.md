# LXC Container Module

Creates and manages LXC containers on Proxmox VE.

## Features

- Creates LXC containers from templates
- Supports privileged and unprivileged containers
- Configurable CPU, memory, and disk resources
- Network configuration with multiple interfaces
- IP configuration (IPv4/IPv6)
- DNS configuration
- SSH key and password authentication
- Container features (nesting, fuse, keyctl, etc.)
- Startup/shutdown ordering
- Container tags and protection

## Usage

### Basic Container

```hcl
module "basic_containers" {
  source = "./modules/lxc_container"

  proxmox_node = "pve01"
  storage_pool = "local-lvm"

  containers = {
    web_server = {
      vm_id            = 100
      name             = "web-01"
      template_file_id = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
      cores            = 2
      memory           = 2048
      disk_size        = 16

      network_interfaces = [{
        name   = "eth0"
        bridge = "vmbr0"
      }]

      ip_configs = [{
        ipv4_address = "192.168.1.100/24"
        ipv4_gateway = "192.168.1.1"
      }]
    }
  }
}
```

### Container with Docker Support (Nesting)

```hcl
module "docker_containers" {
  source = "./modules/lxc_container"

  proxmox_node = "pve01"
  storage_pool = "local-lvm"

  containers = {
    docker_host = {
      vm_id            = 101
      name             = "docker-01"
      template_file_id = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
      unprivileged     = false  # Docker typically requires privileged container
      cores            = 4
      memory           = 8192
      disk_size        = 50

      features = {
        nesting = true  # Required for Docker
        keyctl  = true  # Required for systemd
      }

      network_interfaces = [{
        name   = "eth0"
        bridge = "vmbr0"
      }]

      ip_configs = [{
        ipv4_address = "192.168.1.101/24"
        ipv4_gateway = "192.168.1.1"
      }]

      tags = ["docker", "production"]
    }
  }
}
```

### Multiple Containers with SSH Keys

```hcl
module "app_containers" {
  source = "./modules/lxc_container"

  proxmox_node     = "pve01"
  storage_pool     = "local-lvm"
  network_gateway  = "192.168.1.1"
  default_ssh_keys = ["ssh-rsa AAAA..."]
  default_password = "change-me"

  containers = {
    database = {
      vm_id            = 110
      name             = "db-01"
      template_file_id = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"
      cores            = 4
      memory           = 4096
      disk_size        = 100

      network_interfaces = [{
        name = "eth0"
      }]

      ip_configs = [{
        ipv4_address = "192.168.1.110/24"
      }]

      tags = ["database", "postgresql"]
    }

    cache = {
      vm_id            = 111
      name             = "redis-01"
      template_file_id = "local:vztmpl/alpine-3.22-default_20250617_amd64.tar.xz"
      cores            = 2
      memory           = 2048
      disk_size        = 20

      network_interfaces = [{
        name = "eth0"
      }]

      ip_configs = [{
        ipv4_address = "192.168.1.111/24"
      }]

      tags = ["cache", "redis"]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.85.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_container.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_containers"></a> [containers](#input\_containers) | LXC container specifications | <pre>map(object({<br>    vm_id            = number<br>    name             = string<br>    template_file_id = string # e.g., "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.zst"<br><br>    # Optional configuration<br>    description  = optional(string)<br>    template     = optional(bool, false)<br>    unprivileged = optional(bool, true)<br>    os_type      = optional(string, "debian") # "alpine", "archlinux", "centos", "debian", "fedora", "gentoo", "opensuse", "ubuntu", "unmanaged"<br><br>    # Resources<br>    cores     = optional(number, 1)<br>    cpu_units = optional(number, 1024)<br>    memory    = optional(number, 512)<br>    swap      = optional(number, 0)<br>    disk_size = optional(number, 8)<br><br>    # Network configuration<br>    network_interfaces = optional(list(object({<br>      name        = string<br>      bridge      = optional(string)<br>      enabled     = optional(bool, true)<br>      firewall    = optional(bool, false)<br>      mac_address = optional(string)<br>      rate_limit  = optional(number)<br>      vlan_id     = optional(number)<br>    })), [])<br><br>    # IP configuration<br>    ip_configs = optional(list(object({<br>      ipv4_address = optional(string) # e.g., "192.168.1.100/24"<br>      ipv4_gateway = optional(string)<br>      ipv6_address = optional(string)<br>      ipv6_gateway = optional(string)<br>    })), [])<br><br>    # Authentication<br>    ssh_keys = optional(list(string))<br>    password = optional(string)<br><br>    # Features<br>    features = optional(object({<br>      fuse    = optional(bool, false)<br>      keyctl  = optional(bool, false)<br>      nesting = optional(bool, false)<br>      mount   = optional(list(string), [])<br>    }))<br><br>    # Console<br>    console = optional(object({<br>      enabled   = optional(bool, true)<br>      tty_count = optional(number, 2)<br>      type      = optional(string, "tty")<br>    }))<br><br>    # Startup configuration<br>    startup_order      = optional(number)<br>    startup_up_delay   = optional(number)<br>    startup_down_delay = optional(number)<br><br>    # Behavior<br>    start_on_boot = optional(bool, true)<br>    started       = optional(bool, true)<br>    protection    = optional(bool, false)<br><br>    # Tags<br>    tags = optional(list(string), [])<br>  }))</pre> | `{}` | no |
| <a name="input_default_password"></a> [default\_password](#input\_default\_password) | Default password for container root user | `string` | `null` | no |
| <a name="input_default_ssh_keys"></a> [default\_ssh\_keys](#input\_default\_ssh\_keys) | Default SSH public keys for container root user | `list(string)` | `[]` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Default network bridge for containers | `string` | `"vmbr0"` | no |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | Default network gateway for containers | `string` | `null` | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | The name of the Proxmox node where containers will be created | `string` | n/a | yes |
| <a name="input_storage_pool"></a> [storage\_pool](#input\_storage\_pool) | The storage pool for container disks | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_ids"></a> [container\_ids](#output\_container\_ids) | Map of container names to their VM IDs |
| <a name="output_container_ip_addresses"></a> [container\_ip\_addresses](#output\_container\_ip\_addresses) | Map of container names to their configured IP addresses |
| <a name="output_container_names"></a> [container\_names](#output\_container\_names) | List of all container names |
| <a name="output_container_resources"></a> [container\_resources](#output\_container\_resources) | Raw container resource objects for advanced use cases |
| <a name="output_container_status"></a> [container\_status](#output\_container\_status) | Map of container names to their running status |
| <a name="output_containers"></a> [containers](#output\_containers) | Map of all container details |
<!-- END_TF_DOCS -->
