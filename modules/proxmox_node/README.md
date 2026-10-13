# Proxmox node Module

Per-node host configuration for a Proxmox VE node. Called once per node with `for_each = var.proxmox_nodes`.

Currently manages the APT repositories: adds and enables the `enabled` handles, and disables the `disabled` handles (which ship with a fresh install).

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
| [proxmox_apt_standard_repository.disabled](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/data-sources/apt_standard_repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apt_repositories"></a> [apt\_repositories](#input\_apt\_repositories) | APT standard repository handles to enable or disable on the node | <pre>object({<br/>    enabled  = list(string)<br/>    disabled = list(string)<br/>  })</pre> | n/a | yes |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | The name of the Proxmox node to configure | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
