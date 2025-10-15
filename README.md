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

## Network Architecture

- **ISP Network**: 192.168.0.0/24
  - MikroTik WAN: 192.168.0.98
- **Lab Network**: 192.168.1.0/24 (via MikroTik gateway)
  - Gateway: 192.168.1.1
  - Proxmox Host: 192.168.1.250
  - K3s Control VMs: 192.168.1.210-214 (room for expansion)
  - K3s Worker VMs: 192.168.1.215-220 (room for expansion)
  - Pi 3 Worker: 192.168.1.251
  - Pi 4 Control: 192.168.1.252

## Prerequisites

### Required Software

- [Terraform](https://www.terraform.io/downloads) ~> 1.13
- SSH client with agent running
- Access to Proxmox VE server (v7.0+)

### Proxmox Setup

1. **Template VM**: Create a cloud-init enabled template (ID: 9000)
   - Debian 12 or Ubuntu 22.04 recommended
   - QEMU guest agent installed
   - Cloud-init configured
   - SSH server enabled

2. **API Token**: Create a Proxmox API token
   ```bash
   # On Proxmox host
   pveum role add TerraformProv -privs "VM.Allocate VM.Clone VM.Config.Disk VM.Config.CPU VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit Datastore.AllocateSpace Datastore.Audit"
   pveum user token add terraform-prov@pve terraform-token --privsep=0
   ```
   Save the token secret - you'll need it for `terraform.tfvars`

3. **Network**: Ensure bridge `vmbr0` exists and is configured

## Quick Start

### 1. Clone Repository

```bash
git clone <your-repo-url>
cd terraform-proxmox
```

### 2. Configure Variables

Update `terraform.tfvars` and set:
- `proxmox.endpoint`: Your Proxmox endpoint (e.g., "https://192.168.1.250:8006")
- `proxmox.node`: Your Proxmox node name (e.g., "msi-proxmox")
- `proxmox_auth.api_token`: Your API token from prerequisite step 2
- `vm_cloudinit.ssh_public_key`: Your SSH public key for VM access
- `vm_cloudinit.password`: Password for VM user account

### 3. Terraform

```bash
terraform init
terraform plan
terraform apply
```

Review the planned changes. They Should show:
- 4 VMs to be created
- No existing resources to be modified/destroyed

### 4. Verify VMs

```bash
# List created VMs
terraform output vm_names

# Show IP addresses
terraform output vm_ip_addresses

# Test SSH access (use first control node IP from your config)
ssh admin_test@<control-node-ip>
```

### 5. Export Ansible Inventory (Optional)

```bash
# Generate Ansible inventory file
terraform output -raw ansible_inventory_ini > ../ansible/hosts.ini
```

## Configuration

### VM Specifications

Modify `k3s_vms` in `terraform.tfvars`:

```hcl
k3s_vms = {
  control_01 = {
    vm_id      = 210
    name       = "k3s-main-tf-01"
    cores      = 2
    memory     = 4096
    ip_address = "192.168.1.210"
    role       = "control"
  }
  control_02 = {
    vm_id      = 211
    name       = "k3s-main-tf-02"
    cores      = 2
    memory     = 4096
    ip_address = "192.168.1.211"
    role       = "control"
  }
  worker_01 = {
    vm_id      = 215
    name       = "k3s-worker-tf-01"
    cores      = 2
    memory     = 2048
    ip_address = "192.168.1.215"
    role       = "worker"
  }
  worker_02 = {
    vm_id      = 216
    name       = "k3s-worker-tf-02"
    cores      = 2
    memory     = 2048
    ip_address = "192.168.1.216"
    role       = "worker"
  }
}
```

**IP Addressing Convention:**
VMs use IP addresses that match their VM ID in the last octet. Control nodes start at 210, workers start at 215, with room for expansion.

### Proxmox Connection

Modify `proxmox` and `proxmox_auth` objects in `terraform.tfvars`:

```hcl
proxmox = {
  endpoint = "https://192.168.1.250:8006"
  node     = "msi-proxmox"
  insecure = true
  ssh_user = "root"
}

proxmox_auth = {
  api_token = "terraform-prov@pve!terraform-token=xxx"
  # ... other auth settings
}
```

### Authentication Methods

**API Token (Default)**
- More secure, recommended for production
- Set `proxmox_auth.api_token` in terraform.tfvars
- Keep `api_token` line uncommented in versions.tf

**Username/Password (Alternative)**
- Useful for testing
- Comment out `api_token` line in versions.tf
- Uncomment `username` and `password` lines
- Set values in `proxmox_auth` object

### Network Configuration

VMs are placed on the lab network via MikroTik:
- Network: 192.168.1.0/24
- Gateway: 192.168.1.1 (MikroTik)
- K3s VMs use IP ranges 210-214 (control) and 215-220 (workers)

To change network settings, modify the `network` object in terraform.tfvars:

```hcl
network = {
  gateway     = "192.168.1.1"
  cidr_suffix = "/24"
}
```

And update IP addresses in `k3s_vms` map following the VM ID convention.

## Outputs

### Available Outputs

```bash
# VM identification
terraform output vm_ids
terraform output vm_names

# Network information
terraform output vm_ip_addresses
terraform output control_plane_ips
terraform output worker_node_ips

# Ansible integration
terraform output -raw ansible_inventory_ini
terraform output -json ansible_inventory_json

# Cluster summary
terraform output cluster_summary
```

### Using Outputs with Ansible

```bash
# Export static inventory
terraform output -raw ansible_inventory_ini > ../ansible/hosts.ini

# Or use as dynamic inventory
terraform output -json ansible_inventory_json | jq '.' > ../ansible/inventory/terraform.json
```

## Management

### Adding VMs

1. Add entry to `k3s_vms` in terraform.tfvars
2. Run `terraform apply`
3. New VM will be created without affecting existing ones

### Removing VMs

1. Remove entry from `k3s_vms` in terraform.tfvars
2. Run `terraform apply`
3. VM will be destroyed (backup data first!)

### Updating VM Specs

1. Modify `cores`, `memory` in terraform.tfvars
2. Run `terraform apply`
3. VM will be updated (may require restart)

### Destroying Infrastructure

```bash
# Destroy all VMs
terraform destroy

# Destroy specific VM
terraform destroy -target=proxmox_virtual_environment_vm.k3s_nodes[\"worker_03\"]
```

## Troubleshooting

### VM Creation Timeouts

If VMs timeout during creation:
- Verify QEMU guest agent is installed in template
- Increase `qemu_agent_timeout` in terraform.tfvars
- Check Proxmox task logs for errors

### Authentication Failures

If Terraform cannot connect to Proxmox:
- Verify `proxmox_endpoint` is correct
- Test API token: `pveum user token list terraform-prov@pve`
- Check token has correct permissions
- Verify SSL certificate if not using `insecure = true`

### SSH Connection Issues

If cannot SSH to VMs:
- Verify cloud-init completed: `sudo cloud-init status` on VM
- Check SSH key was injected correctly
- Verify firewall rules allow SSH (port 22)
- Check VM has correct IP address: `ip addr show`

### Template Issues

If cloning fails:
- Verify template VM 9000 exists: `qm list | grep 9000`
- Check template is actually a template: `qm config 9000 | grep template`
- Ensure template has cloud-init drive configured

## Project Structure

```
.
├── versions.tf                 # Terraform & provider configuration
├── variables.tf                # Variable definitions
├── main.tf                     # VM resources
├── outputs.tf                  # Output definitions
├── terraform.tfvars.example    # Example configuration
├── .gitignore                  # Git ignore patterns
├── README.md                   # This file
└── claude.md                   # AI assistant context
```

## Next Steps

After VMs are created:

1. **Install K3s HA Cluster**: Use Ansible to install K3s with HA
   ```bash
   cd ../ansible
   # Install on first VM control node with --cluster-init
   ansible-playbook k3s-ha-install.yml --limit k3s-main-tf-01

   # Join second VM control + Pi4 control, then all workers
   ansible-playbook k3s-ha-install.yml
   ```

2. **Configure kubectl**: Get kubeconfig from any control plane node
   ```bash
   scp admin_test@<control-node-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
   sed -i 's/127.0.0.1/<control-node-ip>/g' ~/.kube/config
   kubectl get nodes
   # Should show 3 control-plane nodes (2 VMs + Pi4) + 3 workers (2 VMs + Pi3)
   ```

3. **Deploy Applications**: Use ArgoCD or kubectl to deploy workloads

## K3s High Availability

This setup implements K3s HA with embedded etcd as per [K3s HA documentation](https://docs.k3s.io/datastore/ha-embedded).

### HA Benefits

- **Fault Tolerance**: Cluster survives 1 control plane node failure
- **No External Database**: Embedded etcd eliminates external dependency
- **Automatic Failover**: K3s handles control plane failover automatically
- **Load Distribution**: API requests distributed across control nodes

### HA Requirements

✅ **Minimum 3 control plane nodes** (for etcd quorum)
✅ **Odd number of control nodes** (3, 5, 7)
✅ **Network connectivity** between all control nodes
✅ **Ports open**: 6443 (API), 2379-2380 (etcd)

### Verifying HA Status

```bash
# Check node status
kubectl get nodes
# Should show 3 nodes with 'control-plane,master' role

# Check etcd cluster health (specify all 3 control node endpoints)
kubectl -n kube-system exec -it <etcd-pod> -- etcdctl \
  --endpoints=https://<control-1-ip>:2379,https://<control-2-ip>:2379,https://<pi4-ip>:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key \
  endpoint health

# Test failover
# Stop one control node and verify cluster remains functional
sudo systemctl stop k3s
kubectl get nodes  # From another control node
```
## Security Considerations

- Use API tokens instead of passwords
- Never commit `terraform.tfvars` to version control
- Use strong passwords for VM user accounts
- Secure state files (contain sensitive data)
- Regularly rotate API tokens
- Use SSH keys instead of passwords for VM access
- Implement Proxmox firewall rules for API access

## Contributing

When making changes:
1. Follow DRY principles (no hardcoded values)
2. Use variables for all configurable values
3. Update documentation for new features
4. Test with `terraform plan` before committing
5. Keep comments concise and clear

## License

[Your License Here]

## Support

For issues and questions:
- Review Proxmox and Terraform documentation
- Check provider issues: https://github.com/bpg/terraform-provider-proxmox/issues

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.13 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.85 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.85.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_vm.k3s_nodes](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_k3s_vms"></a> [k3s\_vms](#input\_k3s\_vms) | K3s cluster VM specifications | <pre>map(object({<br>    vm_id      = number<br>    name       = string<br>    cores      = number<br>    memory     = number<br>    ip_address = string<br>    role       = string<br>  }))</pre> | <pre>{<br>  "control_01": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.210",<br>    "memory": 4096,<br>    "name": "k3s-main-tf-01",<br>    "role": "control",<br>    "vm_id": 210<br>  },<br>  "control_02": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.211",<br>    "memory": 4096,<br>    "name": "k3s-main-tf-02",<br>    "role": "control",<br>    "vm_id": 211<br>  },<br>  "worker_01": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.215",<br>    "memory": 2048,<br>    "name": "k3s-worker-tf-01",<br>    "role": "worker",<br>    "vm_id": 215<br>  },<br>  "worker_02": {<br>    "cores": 2,<br>    "ip_address": "192.168.1.216",<br>    "memory": 2048,<br>    "name": "k3s-worker-tf-02",<br>    "role": "worker",<br>    "vm_id": 216<br>  }<br>}</pre> | no |
| <a name="input_network"></a> [network](#input\_network) | Network configuration for VMs | <pre>object({<br>    gateway     = string<br>    cidr_suffix = string<br>  })</pre> | <pre>{<br>  "cidr_suffix": "/24",<br>  "gateway": "192.168.1.1"<br>}</pre> | no |
| <a name="input_proxmox"></a> [proxmox](#input\_proxmox) | Proxmox connection configuration | <pre>object({<br>    endpoint = string<br>    node     = string<br>    insecure = bool<br>    ssh_user = string<br>  })</pre> | <pre>{<br>  "endpoint": "https://192.168.1.250:8006",<br>  "insecure": true,<br>  "node": "msi-proxmox",<br>  "ssh_user": "root"<br>}</pre> | no |
| <a name="input_proxmox_auth"></a> [proxmox\_auth](#input\_proxmox\_auth) | Proxmox authentication credentials | <pre>object({<br>    api_token    = string<br>    username     = string<br>    password     = string<br>    ssh_password = string<br>  })</pre> | n/a | yes |
| <a name="input_proxmox_infrastructure"></a> [proxmox\_infrastructure](#input\_proxmox\_infrastructure) | Proxmox infrastructure settings | <pre>object({<br>    storage_pool   = string<br>    network_bridge = string<br>    template_vm_id = number<br>  })</pre> | <pre>{<br>  "network_bridge": "vmbr0",<br>  "storage_pool": "local-lvm",<br>  "template_vm_id": 9000<br>}</pre> | no |
| <a name="input_vm_cloudinit"></a> [vm\_cloudinit](#input\_vm\_cloudinit) | Cloud-init configuration for VMs | <pre>object({<br>    username       = string<br>    password       = string<br>    ssh_public_key = string<br>  })</pre> | n/a | yes |
| <a name="input_vm_defaults"></a> [vm\_defaults](#input\_vm\_defaults) | Default VM configuration | <pre>object({<br>    disk_interface = string<br>    disk_size      = number<br>    qemu_agent = object({<br>      enabled = bool<br>      timeout = string<br>    })<br>    behavior = object({<br>      on_boot         = bool<br>      started         = bool<br>      stop_on_destroy = bool<br>    })<br>  })</pre> | <pre>{<br>  "behavior": {<br>    "on_boot": true,<br>    "started": true,<br>    "stop_on_destroy": true<br>  },<br>  "disk_interface": "scsi0",<br>  "disk_size": 17,<br>  "qemu_agent": {<br>    "enabled": true,<br>    "timeout": "15m"<br>  }<br>}</pre> | no |

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
| <a name="output_worker_node_ips"></a> [worker\_node\_ips](#output\_worker\_node\_ips) | IP addresses of worker nodes |
<!-- END_TF_DOCS -->
