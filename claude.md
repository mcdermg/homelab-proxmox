# Proxmox VM Terraform Project

## Project Overview

This is a Terraform project for managing virtual machines on a Proxmox VE server using Infrastructure as Code. The project provisions VMs and lsc containers amongst other resources in Proxmox. Some VMs are part of a **K3s Kubernetes High Availability cluster** with **embedded etcd**. VMs are managed by Terraform.

## K3s HA Architecture

### Cluster Design

**High Availability Setup with Embedded Etcd:**
- 3 control plane nodes (minimum for HA quorum)
  - 2 VMs on Proxmox (IaC managed by Terraform, config management by Ansible)
  - 1 Raspberry Pi 4 at 192.168.1.252 (config management by Ansible)
- 3 worker nodes
  - 2 VMs on Proxmox (IaC managed by Terraform, config management by Ansible)
  - 1 Raspberry Pi 3 at 192.168.1.251 (config management by Ansible)

**Why 3 Control Nodes?**
K3s embedded etcd requires an odd number of control nodes (3, 5, 7) for quorum. With 3 nodes:
- Cluster tolerates 1 control plane failure
- Etcd maintains quorum with 2/3 nodes
- See: https://docs.k3s.io/datastore/ha-embedded

### Node Distribution

**Terraform-Managed (Proxmox VMs):**
- `k3s-main-tf-01` (192.168.1.210) - Control plane, VM ID 210
- `k3s-main-tf-02` (192.168.1.211) - Control plane, VM ID 211
- `k3s-worker-tf-01` (192.168.1.215) - Worker, VM ID 215
- `k3s-worker-tf-02` (192.168.1.216) - Worker, VM ID 216
- `k3s-worker-tf-03` (192.168.1.217) - Worker, VM ID 217

**Ansible-Managed (Physical Raspberry Pis):**
- Pi 4 (192.168.1.252) - Control plane [HA quorum]
- Pi 3 (192.168.1.251) - Worker

### IP Addressing Scheme

**Convention:** Last octet matches VM ID
Control nodes staring at VM ID 210 so last IP octet xxx.xxx.x.210 and going to xxx.xxx.x.215 although we only use two for now with room for future expansion in Proxmox VM ID and IP range as required.

## Network Architecture

### Network Topology
- **ISP Network**: `192.168.0.0/24` (Gateway: `192.168.0.1`)
- **Lab Network**: `192.168.1.0/24` (Gateway: `192.168.1.1` via MikroTik)
  - Proxmox Host: `192.168.1.250:8006`
  - K3s Control VMs: `192.168.1.210-214` (note not all used initially and room for future expansion is in place)
  - K3s Worker VMs: `192.168.1.214-220` (note not all used initially and room for future expansion is in place)
  - Container (ISP Monitor): `192.168.1.249`
  - Pi 3 (K3s Worker): `192.168.1.251`
  - Pi 4 (K3s Control): `192.168.1.252`
  - TP-Link Switch: `192.168.1.253`

### Cluster Network Architecture
```
ISP Router (192.168.0.1)
    │
    └── MikroTik Router (192.168.0.98 WAN / 192.168.1.1 LAN)
            │
            └── Lab Network (192.168.1.0/24)
                    │
                    ├── Proxmox Host (192.168.1.250)
                    │   ├── k3s-main-tf-01 (192.168.1.210) - Control VM
                    │   ├── k3s-main-tf-02 (192.168.1.211) - Control VM
                    │   ├── k3s-worker-tf-01 (192.168.1.215) - Worker VM
                    │   ├── k3s-worker-tf-02 (192.168.1.216) - Worker VM
                    │   └── k3s-worker-tf-03 (192.168.1.217) - Worker VM
                    ├── Container (192.168.1.249) - ISP Monitor
                    ├── Pi 3 (192.168.1.251)
                    ├── Pi 4 (192.168.1.252)
                    └── TP-Link Switch (192.168.1.253)
```

**Key Points:**
- VMs are on the **lab network** (192.168.1.x), not ISP network
- MikroTik provides routing between networks
- K3s cluster is fully contained within lab network
- IP range 192.168.1.210-220 reserved for K3s cluster VMs
- Static leases at 192.168.1.249-253 for infrastructure devices

## File Structure

```
terraform-proxmox/
├── versions.tf                 # Terraform & provider version constraints, provider config
├── variables.tf                # All variable definitions with types and defaults
├── main.tf                     # VM resource definitions using for_each
├── outputs.tf                  # Outputs for Ansible integration and VM info
├── terraform.tfvars            # variable values
├── .gitignore                  # Git ignore patterns (excludes .tfvars, state files)
├── .terraform.lock.hcl         # Provider version lock file (auto-generated)
├── README.md                   # User-facing documentation
└── claude.md                   # This file - AI assistant context
```

## Coding Conventions

### Critical Rules

1. **DRY Principle**: NEVER hardcode values that are used in multiple places
   - ❌ BAD: `ip_address = "192.168.0.90"` scattered throughout
   - ✅ GOOD: `ip_address = var.k3s_vms["control_01"].ip_address`

2. **Comment Style**: Simple section headers only
   - ❌ BAD: `# ============================================================================`
   - ✅ GOOD: `# VM CONFIGURATION`

3. **Variable Usage**: Use variables for ALL configurable values
   - VM specs, IPs, storage, network settings, etc.
   - If it might change, it's a variable

4. **Use Locals for Computed Values**: Extract/compute from variables
   ```hcl
   locals {
     vm_ip_configs = {
       for key, vm in var.k3s_vms :
       key => "${vm.ip_address}${var.network_cidr_suffix}"
     }
   }
   ```

5. **Use `for_each` for Collections**: Never duplicate resource blocks
   - VMs: `for_each = var.k3s_vms`
   - Single resource definition handles all nodes

### Resource Naming

- Resource names: snake_case (e.g., `k3s_nodes`, `control_plane`)
- Variable names: snake_case with descriptive names (e.g., `proxmox_endpoint`, `vm_username`)
- VM names: kebab-case (e.g., `k3s-main-tf-01`, `k3s-worker-tf-01`)
- Tags: lowercase, descriptive (e.g., `["terraform", "k3s", "control"]`)
- Comments: Concise, describe purpose not implementation

## Proxmox-Specific Considerations

### Authentication Methods

**API Token (Primary - Recommended)**
- More secure, granular permissions
- Token format: `username@realm!tokenid=uuid`
- Create token: `pveum user token add terraform-prov@pve terraform-token --privsep=0`
- Set in terraform.tfvars: `proxmox_api_token = "terraform-prov@pve!terraform-token=xxx"`

**Username/Password (Alternative)**
- Simpler but less secure
- Useful for initial testing
- Comment out `api_token` in versions.tf and uncomment username/password

### Provider Configuration

The BGP Proxmox provider (`bpg/proxmox`) is used instead of the Telmate provider:
- Better cloud-init support
- More active maintenance
- Native Terraform Provider Protocol support
- Better VM cloning capabilities

### Template Requirements

**Template VM (ID 9000) must have:**
- ✅ Cloud-init configured and installed
- ✅ QEMU guest agent installed and enabled
- ✅ Base disk size (10GB minimum)
- ✅ Network interface configured
- ✅ SSH server installed

**Creating a template:**
```bash
# On Proxmox host
qm create 9000 --name debian-12-template --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9000 /path/to/debian-12-generic-amd64.qcow2 local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

### Disk Operations

- **Disk Interface**: Use `scsi0` for best performance with virtio-scsi controller
- **Disk Resizing**: Specify total size in `disk.size` - provider handles expansion
- **File Format**: Use `raw` for better performance vs `qcow2`
- **Storage Pool**: `local-lvm` is typical for VM disks

### Network Configuration

- **Bridge**: `vmbr0` is the default Linux bridge in Proxmox
- **VLAN**: Not used in this setup (single flat network)
- **MAC Address**: Auto-assigned by Proxmox, captured in outputs

### Cloud-Init Configuration

Cloud-init handles:
- User creation (`var.vm_username`)
- Password setting (`var.vm_password`)
- SSH key injection (`var.ssh_public_key`)
- Network configuration (static IP, gateway, DNS)
- Hostname setting

### QEMU Guest Agent

**Critical for Terraform operations:**
- Enables IP address detection
- Allows graceful shutdown
- Provides VM state information
- Must be enabled in template and running in guest

**Timeout considerations:**
- First boot can be slow (cloud-init initialization)
- Set reasonable timeout: `15m` for initial provisioning
- Agent must start before Terraform can complete

### VM Lifecycle

**Creation Flow:**
1. Clone template VM
2. Apply cloud-init configuration
3. Resize disk (if larger than template)
4. Configure CPU/memory
5. Set network configuration
6. Start VM
7. Wait for QEMU agent
8. Verify IP assignment

**Destruction Flow:**
1. Stop VM (if `stop_on_destroy = true`)
2. Delete VM and associated resources
3. Remove from Proxmox

## Variable Structure

### Variable Organization
Variables are grouped by function using object types:
- **proxmox**: Connection settings (endpoint, node, insecure, ssh_user)
- **proxmox_auth**: Authentication credentials (api_token, username, password)
- **proxmox_infrastructure**: Infrastructure settings (storage, network, template)
- **vm_defaults**: Default VM configuration (disk, qemu agent, behavior)
- **network**: Network configuration (gateway, CIDR suffix)
- **vm_cloudinit**: Cloud-init settings (user, password, SSH keys)
- **k3s_vms**: K3s cluster VM specifications (map of objects)

### Complex Variable Types

**Proxmox Connection** (object):
```hcl
variable "proxmox" {
  type = object({
    endpoint  = string
    node      = string
    insecure  = bool
    ssh_user  = string
  })
}
```

**Proxmox Authentication** (object, sensitive):
```hcl
variable "proxmox_auth" {
  type = object({
    api_token    = string
    username     = string
    password     = string
    ssh_password = string
  })
  sensitive = true
}
```

**VM Defaults** (nested object):
```hcl
variable "vm_defaults" {
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
}
```

**K3s VMs Map** (map of objects):
```hcl
variable "k3s_vms" {
  type = map(object({
    vm_id      = number
    name       = string
    cores      = number
    memory     = number
    ip_address = string
    role       = string
  }))
}
```

**Usage in resources:**
```hcl
resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  for_each = var.k3s_vms

  name      = each.value.name
  node_name = var.proxmox.node
  vm_id     = each.value.vm_id

  disk {
    datastore_id = var.proxmox_infrastructure.storage_pool
    interface    = var.vm_defaults.disk_interface
    size         = var.vm_defaults.disk_size
  }

  initialization {
    ip_config {
      ipv4 {
        gateway = var.network.gateway
      }
    }
    user_account {
      username = var.vm_cloudinit.username
      password = var.vm_cloudinit.password
      keys     = [var.vm_cloudinit.ssh_public_key]
    }
  }
}
```

### With MikroTik Network

**A completely separate repository manages all MikroTik configuration via IaC and Terraform.

- VMs are on the **lab network** (192.168.1.x), not ISP network
- MikroTik (192.168.1.1) provides routing and gateway
- K3s services can be exposed via MikroTik port forwards
- Consider adding MikroTik firewall rules for K3s API server (port 6443)
- Lab network is isolated from ISP network via MikroTik

## Anti-Patterns to Avoid

❌ **Hardcoding values used multiple times**
❌ **Creating duplicate resource blocks instead of using `for_each`**
❌ **Using decorative comment borders**
❌ **Modifying VMs manually in Proxmox UI (state drift)**
❌ **Forgetting to update `terraform.tfvars` when changing infrastructure**
❌ **Using inline values instead of variables in resources**
❌ **Not using `terraform plan` before `apply`**
❌ **Committing `terraform.tfvars` to version control (contains secrets)**

## Terraform Best Practices

### State Management
- Never commit `terraform.tfvars` (contains credentials)
- Keep state file secure (contains IP addresses, VM IDs)
- Use state locking to prevent concurrent modifications

### Workflow
1. Edit variables or resources
2. Run `terraform fmt` to format
3. Run `terraform validate` to check syntax
4. Run `terraform plan` to preview changes
5. Review plan output carefully
6. Run `terraform apply` to implement
7. Commit `.tf` files (NOT `.tfvars`) to git

### Provider Version
- Currently using `bpg/proxmox` version but this may change and update in future.

### Security Considerations

1. **API Tokens**: Use instead of passwords where possible
2. **SSH Keys**: Never commit private keys
3. **Passwords**: Use strong passwords, store securely
4. **tfvars**: Add to .gitignore, never commit
5. **State Files**: Contain sensitive data, secure appropriately

## Troubleshooting

### Common Issues

**"timeout while waiting for the virtual machine"**
- QEMU agent not installed in template
- VM taking too long to boot
- Increase `qemu_agent_timeout`

**"resource not found" on apply**
- Template VM (9000) doesn't exist
- Wrong storage pool specified
- Network bridge doesn't exist

**"insufficient permissions"**
- API token lacks required privileges
- Create proper role: `pveum role add TerraformProv -privs "VM.Allocate VM.Clone..."`
- Assign to user: `pveum aclmod / -user terraform-prov@pve -role TerraformProv`

**VMs don't get IP addresses**
- Cloud-init not configured in template
- Network configuration error
- Check gateway is reachable (192.168.1.1)
- Verify MikroTik routing is working
- Check DHCP not conflicting (using static IPs)

**Disk resize doesn't work**
- Specify total size, not increment
- Template base + expansion = total
- Use `17` for 10GB template + 7GB expansion


**Check Proxmox task logs:**
- Web UI: Datacenter → Node → Task History
- CLI: `qm status <vmid>` and `qm config <vmid>`

**Verify cloud-init:**
```bash
# On VM after boot
sudo cloud-init status
sudo cloud-init query --all
```

## When Making Changes

1. Always check if a value should be a variable
2. Always use existing variables rather than creating new ones
3. Always maintain DRY principles
4. Always preserve resource dependencies
5. Always keep comments simple and clean
6. Test changes with `terraform plan` and NEVER run apply
7. Consider impact on Ansible integration if it is used
8. Document breaking changes in commit messages

## Proxmox Provider Resources Reference

**VM Resource** (`proxmox_virtual_environment_vm`):
- `clone`: Clone from template
- `cpu`: CPU configuration
- `memory`: Memory allocation
- `disk`: Disk configuration
- `network_device`: Network interfaces
- `initialization`: Cloud-init settings
- `agent`: QEMU guest agent config

**Key Attributes:**
- `vm_id`: Unique VM identifier
- `node_name`: Proxmox node to create VM on
- `started`: Power state after creation
- `on_boot`: Auto-start on Proxmox boot

## Additional Resources

- [BGP Proxmox Provider Docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)

## Safeguards
1. Always check if a value should be a variable
2. Always try to use existing variables rather than creating new ones
3. Always maintain DRY principles
5. Always keep comments simple and clean
6. Test changes with `terraform plan` before committing
7. NEVER run terraform apply
8. NEVER run terraform destroy
9. NEVER run terraform destroy -auto-approve
10. NEVER run terraform destroy -auto-approve
