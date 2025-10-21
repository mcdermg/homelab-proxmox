# k3s_cluster Module

Creates a K3s cluster on Proxmox by cloning VMs from a template with cloud-init configuration.

## Features

- Creates control plane and worker nodes from a Proxmox VM template
- Supports role-based node configuration (control/worker)
- Cloud-init integration for automated VM setup
- Generates Ansible inventory outputs (JSON and INI formats)
- Flexible VM specifications per node

## Usage

```hcl
module "k3s_cluster" {
  source = "./modules/k3s_cluster"

  cluster_nodes = {
    control_01 = {
      vm_id      = 210
      name       = "k3s-control-01"
      cores      = 2
      memory     = 4096
      ip_address = "192.168.1.210"
      role       = "control"
    }
    worker_01 = {
      vm_id      = 215
      name       = "k3s-worker-01"
      cores      = 2
      memory     = 2048
      ip_address = "192.168.1.215"
      role       = "worker"
    }
  }

  # Proxmox settings
  proxmox_node   = "pve01"
  template_vm_id = 9000
  storage_pool   = "local-lvm"
  network_bridge = "vmbr0"

  # Network configuration
  network_gateway     = "192.168.1.1"
  network_cidr_suffix = "/24"

  # Cloud-init configuration
  cloudinit_username = "ubuntu"
  cloudinit_password = "your-password"
  cloudinit_ssh_key  = "ssh-rsa AAAA..."
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
| [proxmox_virtual_environment_vm.k3s_nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudinit_password"></a> [cloudinit\_password](#input\_cloudinit\_password) | Cloud-init user account password | `string` | n/a | yes |
| <a name="input_cloudinit_ssh_key"></a> [cloudinit\_ssh\_key](#input\_cloudinit\_ssh\_key) | SSH public key for cloud-init user | `string` | `""` | no |
| <a name="input_cloudinit_username"></a> [cloudinit\_username](#input\_cloudinit\_username) | Cloud-init user account username | `string` | n/a | yes |
| <a name="input_cluster_nodes"></a> [cluster\_nodes](#input\_cluster\_nodes) | K3s cluster node specifications | <pre>map(object({<br>    vm_id      = number<br>    name       = string<br>    cores      = number<br>    memory     = number<br>    ip_address = string<br>    role       = string # "control" or "worker"<br>  }))</pre> | n/a | yes |
| <a name="input_default_disk_interface"></a> [default\_disk\_interface](#input\_default\_disk\_interface) | Default disk interface (e.g., 'scsi0') | `string` | `"scsi0"` | no |
| <a name="input_default_disk_size"></a> [default\_disk\_size](#input\_default\_disk\_size) | Default disk size in GB | `number` | `17` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | The network bridge for VM network devices | `string` | n/a | yes |
| <a name="input_network_cidr_suffix"></a> [network\_cidr\_suffix](#input\_network\_cidr\_suffix) | CIDR suffix for IP addresses (e.g., '/24') | `string` | n/a | yes |
| <a name="input_network_gateway"></a> [network\_gateway](#input\_network\_gateway) | The network gateway for VMs | `string` | n/a | yes |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | The Proxmox node where VMs will be created | `string` | n/a | yes |
| <a name="input_qemu_agent_enabled"></a> [qemu\_agent\_enabled](#input\_qemu\_agent\_enabled) | Enable QEMU guest agent | `bool` | `false` | no |
| <a name="input_qemu_agent_timeout"></a> [qemu\_agent\_timeout](#input\_qemu\_agent\_timeout) | QEMU agent timeout | `string` | `"4m"` | no |
| <a name="input_storage_pool"></a> [storage\_pool](#input\_storage\_pool) | The storage pool for VM disks and cloud-init | `string` | n/a | yes |
| <a name="input_template_vm_id"></a> [template\_vm\_id](#input\_template\_vm\_id) | The VM ID of the template to clone from | `number` | n/a | yes |
| <a name="input_vm_on_boot"></a> [vm\_on\_boot](#input\_vm\_on\_boot) | Start VM on boot | `bool` | `true` | no |
| <a name="input_vm_started"></a> [vm\_started](#input\_vm\_started) | Start VM after creation | `bool` | `true` | no |
| <a name="input_vm_stop_on_destroy"></a> [vm\_stop\_on\_destroy](#input\_vm\_stop\_on\_destroy) | Stop VM when destroying | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ansible_inventory_ini"></a> [ansible\_inventory\_ini](#output\_ansible\_inventory\_ini) | Ansible inventory in INI format |
| <a name="output_ansible_inventory_json"></a> [ansible\_inventory\_json](#output\_ansible\_inventory\_json) | Ansible inventory in JSON format |
| <a name="output_cluster_summary"></a> [cluster\_summary](#output\_cluster\_summary) | High-level cluster configuration summary |
| <a name="output_control_plane_ips"></a> [control\_plane\_ips](#output\_control\_plane\_ips) | IP addresses of control plane nodes |
| <a name="output_vm_ids"></a> [vm\_ids](#output\_vm\_ids) | Map of VM names to their VM IDs |
| <a name="output_vm_ip_addresses"></a> [vm\_ip\_addresses](#output\_vm\_ip\_addresses) | Map of VM names to their IP addresses |
| <a name="output_vm_ipv4_addresses"></a> [vm\_ipv4\_addresses](#output\_vm\_ipv4\_addresses) | IPv4 addresses reported by QEMU agent |
| <a name="output_vm_mac_addresses"></a> [vm\_mac\_addresses](#output\_vm\_mac\_addresses) | MAC addresses of VM network interfaces |
| <a name="output_vm_names"></a> [vm\_names](#output\_vm\_names) | List of all VM names |
| <a name="output_vm_network_details"></a> [vm\_network\_details](#output\_vm\_network\_details) | Complete network configuration for all VMs |
| <a name="output_vm_resources"></a> [vm\_resources](#output\_vm\_resources) | Raw VM resource objects for advanced use cases |
| <a name="output_worker_node_ips"></a> [worker\_node\_ips](#output\_worker\_node\_ips) | IP addresses of worker nodes |
<!-- END_TF_DOCS -->
