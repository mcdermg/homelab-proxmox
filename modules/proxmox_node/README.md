# Proxmox node Module

Per-node host configuration for a Proxmox VE node. Called once per node with `for_each = var.proxmox_nodes`.

Manages:

- **APT repositories:** adds and enables the `enabled` handles, and disables the `disabled` handles (which ship with a fresh install).
- **ZFS pool:** creates the node's pool with `add_storage = false`. The pool name is the same on every node, so the root module manages one cluster-wide storage entry for it.

## Usage

```hcl
module "proxmox_node" {
  source   = "./modules/proxmox_node"
  for_each = var.proxmox_nodes

  node_name = each.key

  apt_repositories = {
    enabled  = ["no-subscription"]
    disabled = ["enterprise", "ceph-squid-enterprise"]
  }

  zfs_pool_name = "nvme-storage"
  zfs_pool = {
    devices   = ["/dev/disk/by-id/nvme-..."]
    raidlevel = "single"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [proxmox_apt_repository.disabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_repository) | resource |
| [proxmox_apt_repository.enabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_repository) | resource |
| [proxmox_apt_standard_repository.enabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/apt_standard_repository) | resource |
| [proxmox_node_disk_zfs.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/node_disk_zfs) | resource |
| [proxmox_apt_standard_repository.disabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/apt_standard_repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apt_repositories"></a> [apt\_repositories](#input\_apt\_repositories) | APT standard repository handles to enable or disable on the node | <pre>object({<br/>    enabled  = list(string)<br/>    disabled = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | The name of the Proxmox node to configure | `string` | n/a | yes |
| <a name="input_zfs_pool"></a> [zfs\_pool](#input\_zfs\_pool) | Disks and RAID level for the node's ZFS pool | <pre>object({<br/>    devices   = list(string)<br/>    raidlevel = string<br/>  })</pre> | n/a | yes |
| <a name="input_zfs_pool_name"></a> [zfs\_pool\_name](#input\_zfs\_pool\_name) | Name of the node's ZFS pool, the same on every node so one storage entry covers them all | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
