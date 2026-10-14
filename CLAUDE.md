# Proxmox VM OpenTofu Project

## Project Overview

This is an OpenTofu project for managing virtual machines on a Proxmox VE server using Infrastructure as Code. The project provisions VMs and LXC containers amongst other resources in Proxmox. Some VMs are part of a **K3s Kubernetes High Availability cluster** with **embedded etcd**. VMs are managed by OpenTofu. Use `tofu` (aliased to `tf`), never `terraform`: the state and lock file are OpenTofu-only.

##  OpenTofu MCP
Use the OpenTofu MCP to check for documentation, providers, modules, resources etc etc. Use the MCP over generic web where at all possible and only fall back to that if specific documentation or attributes etc cannot be found via MCP.

## K3s HA Architecture

### Cluster Design

**High Availability Setup with Embedded Etcd:**
- 3 control plane nodes (minimum for HA quorum)
  - 2 VMs on Proxmox (IaC managed by OpenTofu, config management by Ansible)
  - 1 Raspberry Pi 4 at 192.168.1.241 (config management by Ansible)
- 3 worker nodes
  - 2 VMs on Proxmox (IaC managed by OpenTofu, config management by Ansible)
  - 1 Raspberry Pi 3 at 192.168.1.242 (config management by Ansible)

**Why 3 Control Nodes?**
K3s embedded etcd requires an odd number of control nodes (3, 5, 7) for quorum. With 3 nodes:
- Cluster tolerates 1 control plane failure
- Etcd maintains quorum with 2/3 nodes
- See: https://docs.k3s.io/datastore/ha-embedded

### Node Distribution

**OpenTofu-Managed (Proxmox VMs):**
- `k3s-control-tf-01` (192.168.1.210) - Control plane, VM ID 210, pve01
- `k3s-control-tf-02` (192.168.1.211) - Control plane, VM ID 211, pve02
- `k3s-worker-tf-01` (192.168.1.215) - Worker, VM ID 215, pve01
- `k3s-worker-tf-02` (192.168.1.216) - Worker, VM ID 216, pve01
- `k3s-worker-tf-03` to `-05` (192.168.1.217–219) - Workers, VM IDs 217–219, pve02

Placement is `node_name` per entry (validated against `proxmox_nodes`): required in `k3s_vms`, optional in `lxc_containers` where it falls back to `proxmox.node`. The two Proxmox control planes sit on different nodes so one node failure doesn't take etcd quorum with it.

**Ansible-Managed (Physical Raspberry Pis):**
- Pi 4 (192.168.1.241) - Control plane [HA quorum]
- Pi 3 (192.168.1.242) - Worker

### IP Addressing Scheme

**Convention:** Last octet matches VM ID
Control plane VMs use VM IDs/IPs 210–214 and workers use 215–220, set as ranges in `var.k3s_roles`. A `k3s_vms` entry is keyed `<role>_<NN>` and only sets `node_name` (plus optional `cores`/`memory`); the VM ID, IP and name are derived in `local.k3s_vms` in `main.tf`, so `worker_03` becomes VM 217, `192.168.1.217`, `k3s-worker-tf-03`.

## Network Architecture

### Network Topology
- **ISP Network**: `192.168.0.0/24` (Gateway: `192.168.0.1`)
- **Lab Network**: `192.168.1.0/24` (Gateway: `192.168.1.1` via MikroTik)
  - Proxmox pve01: `192.168.1.250:8006`
  - Proxmox pve02: `192.168.1.251:8006`
  - K3s Control VMs: `192.168.1.210-214` (note not all used initially and room for future expansion is in place)
  - K3s Worker VMs: `192.168.1.215-220` (note not all used initially and room for future expansion is in place)
  - Container (ISP Monitor): `192.168.1.249`
  - Pi 4 (K3s Control): `192.168.1.241`
  - Pi 3 (K3s Worker): `192.168.1.242`
  - TP-Link Switch: `192.168.1.254`

### Lab IP Layout
| Range | Use |
|---|---|
| `.1` | MikroTik |
| `.2`–`.9` | Network gear (spare) |
| `.10`–`.49` | k8s LoadBalancer pool (MetalLB) |
| `.50`–`.99` | DHCP pool (set in mikrotik-hapac2) |
| `.100`–`.199` | LXCs (VMID = last octet) |
| `.200`–`.239` | k3s VMs (VMID = last octet) |
| `.240`–`.248` | Pis and other physical hosts |
| `.249` | MikroTik ISP monitor container |
| `.250`–`.252` | Proxmox nodes (pve01, pve02, spare) |
| `.253` | Proxmox QDevice (reserved) |
| `.254` | TP-Link switch |

### Cluster Network Architecture
```
ISP Router (192.168.0.1)
    │
    └── MikroTik Router (192.168.0.98 WAN / 192.168.1.1 LAN)
            │
            └── Lab Network (192.168.1.0/24)
                    │
                    ├── Proxmox pve01 (192.168.1.250)
                    │   ├── k3s-control-tf-01 (192.168.1.210) - Control VM
                    │   ├── k3s-worker-tf-01 (192.168.1.215) - Worker VM
                    │   └── k3s-worker-tf-02 (192.168.1.216) - Worker VM
                    ├── Proxmox pve02 (192.168.1.251)
                    │   ├── k3s-control-tf-02 (192.168.1.211) - Control VM
                    │   └── k3s-worker-tf-03 to -05 (192.168.1.217–219) - Worker VMs
                    ├── Pi 4 (192.168.1.241)
                    ├── Pi 3 (192.168.1.242)
                    ├── Container (192.168.1.249) - ISP Monitor
                    └── TP-Link Switch (192.168.1.254)
```

**Key Points:**
- VMs are on the **lab network** (192.168.1.x), not ISP network
- MikroTik provides routing between networks
- K3s cluster is fully contained within lab network
- IP range 192.168.1.210-220 reserved for K3s cluster VMs
- Static leases for physical devices at 192.168.1.241-242 and 192.168.1.250-254, outside the DHCP pool (192.168.1.50-99)

## File Structure

```
homelab-proxmox/
├── backend.tf                  # Remote state in Cloudflare R2 (s3 backend, use_lockfile)
├── versions.tf                 # OpenTofu version (language block), provider constraints and config
├── variables.tf                # All variable definitions with types and defaults
├── main.tf                     # Module calls (downloads, k3s_cluster, lxc_containers) and generated Ansible files
├── cloudflare.tf               # Cloudflare tunnel, DNS records and Access applications
├── outputs.tf                  # Root outputs (currently none)
├── terraform.tfvars            # Variable values (gitignored)
├── modules/
│   ├── proxmox_node/           # Per-node host config (APT repos, ZFS pool), one instance per node
│   ├── k3s_cluster/            # Template 9000 and the k3s VMs
│   ├── lxc_container/          # LXC containers
│   ├── download_file/          # ISO, LXC template and VM image downloads
│   └── cloudflare_dns/         # Tunnel DNS records
├── templates/                  # Template for the generated ansible/hosts.ini
├── ansible/                    # Playbooks and roles (hosts.ini is generated by OpenTofu)
├── .gitignore                  # Git ignore patterns (excludes .tfvars, state files, hosts.ini)
├── README.md                   # User-facing documentation
└── CLAUDE.md                   # This file - AI assistant context
```

## Coding Conventions

### Critical Rules

1. **DRY Principle**: NEVER hardcode values that are used in multiple places
   - ❌ BAD: `ip_address = "192.168.0.90"` scattered throughout
   - ✅ GOOD: `ip_address = local.k3s_vms["control_01"].ip_address`

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
       for key, vm in var.cluster_nodes :
       key => "${vm.ip_address}${var.network_cidr_suffix}"
     }
   }
   ```

5. **Use `for_each` for Collections**: Never duplicate resource blocks
   - VMs: `for_each = local.k3s_vms`
   - Single resource definition handles all nodes

### Resource Naming

- Resource names: snake_case (e.g., `k3s_nodes`, `control_plane`)
- Variable names: snake_case with descriptive names (e.g., `template_storage_pool`, `network_bridge`)
- VM names: kebab-case (e.g., `k3s-control-tf-01`, `k3s-worker-tf-01`)
- Tags: lowercase, descriptive (e.g., `["terraform", "k3s", "control"]`)
- Comments: Concise, describe purpose not implementation

## Proxmox-Specific Considerations

### Authentication Methods

**API Token (in use)**
- Token format: `username@realm!tokenid=uuid`
- Create token: `pveum user token add terraform-prov@pve terraform-token --privsep=0`
- Set in terraform.tfvars: `proxmox_auth.api_token = "terraform-prov@pve!terraform-token=xxx"`
- The Ansible inventory gets the token split into `pm_api_token_id` / `pm_api_token_secret` for the `community.proxmox` calls
- Some operations only work as `root@pam` (VM `arch`, feature flags on privileged containers); see the bpg provider docs

**SSH:** the provider's SSH port is only set per node, via `ssh { node {} }` built from `var.proxmox_nodes`. Both nodes use `var.proxmox.ssh_port` (default 2222).

### Provider Configuration

The bpg Proxmox provider (`bpg/proxmox`) is used instead of the Telmate provider:
- Better cloud-init support
- More active maintenance
- Native Terraform Provider Protocol support
- Better VM cloning capabilities

### Template Requirements

Each node gets its own k3s template (9000 on pve01, 9001 on pve02, set by `template_vm_id` in `var.proxmox_nodes`), created by OpenTofu in `modules/k3s_cluster` (`proxmox_virtual_environment_vm.template`) from that node's copy of the Debian 13 `generic` cloud image downloaded by `vm_image_downloads`. Templates on local ZFS can't be cloned to another node, so each k3s VM is a full clone of the template on its own node. Nothing needs to be built by hand with `qm`.

### Disk Operations

- **Disk Interface**: Use `scsi0` for best performance with virtio-scsi controller
- **Disk Resizing**: Specify total size in `disk.size` - provider handles expansion
- **File Format**: Use `raw` for better performance vs `qcow2`
- **Storage Pool**: VM and container disks use `nvme-storage` (a ZFS pool per node from `module.proxmox_node`, plus one cluster-wide storage entry in `main.tf`), ISOs and templates use `nvme-files`, and the k3s templates (9000, 9001) are also on `nvme-storage`

### Network Configuration

- **Bridge**: `vmbr0` is the default Linux bridge in Proxmox
- **VLAN**: Not used in this setup (single flat network)
- **MAC Address**: Auto-assigned by Proxmox, captured in outputs

### Cloud-Init Configuration

Cloud-init handles:
- User creation (`var.vm_cloudinit.username`)
- Password setting (`var.vm_cloudinit.password`)
- SSH key injection (read from `var.ssh_public_key_file`, default `~/.ssh/id_ed25519.pub`; also used as root's key on every LXC)
- Network configuration (static IP, gateway, DNS)
- Hostname setting

### QEMU Guest Agent

**Critical for OpenTofu operations:**
- Enables IP address detection
- Allows graceful shutdown
- Provides VM state information
- Must be enabled in template and running in guest

**Timeout considerations:**
- First boot can be slow (cloud-init initialization)
- Set reasonable timeout: `15m` for initial provisioning
- Agent must start before OpenTofu can complete

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
- **proxmox**: Connection settings (endpoint, default guest node, insecure, ssh_user, ssh_port)
- **proxmox_auth**: Proxmox API token (`api_token` only; SSH uses the agent)
- **proxmox_nodes**: Per node: SSH address, k3s template VM ID and ZFS pool disks (`/dev/disk/by-id` paths); drives the provider SSH blocks, `module.proxmox_node` and the `nvme-storage` entry's node list
- **apt_repositories**: APT standard repo handles to enable/disable on every node
- **network_bridge**: Proxmox network bridge
- **iso_downloads**, **lxc_template_downloads**, **vm_image_downloads**: Files to download to Proxmox storage
- **k3s_defaults**: Default k3s VM configuration (disk, qemu agent, behavior)
- **network**: Network configuration (gateway, CIDR suffix)
- **ssh_public_key_file**: Path to the public key put on every VM and LXC (default `~/.ssh/id_ed25519.pub`)
- **vm_cloudinit**: Cloud-init settings (user, password)
- **k3s_roles**: Per role (control, worker): VM ID range and default cores/memory
- **k3s_vms**: k3s VMs keyed `<role>_<NN>`, each with `node_name` and optional `cores`/`memory`
- **k3s_pi_01_ip**, **k3s_pi_02_ip**: Raspberry Pi IPs for the generated Ansible inventory
- **lxc_defaults**, **lxc_containers**: LXC defaults and container specifications (map of objects)
- **gitea_db_password**, **gitea_admin_password**, **postgres_admin_password**, **pulse_admin_password**: app passwords, passed to Ansible only through the generated (gitignored) `ansible/hosts.ini`; letters, digits, `.`, `_`, `-` only
- **cloudflare_\***: Cloudflare API token, zone and account for the tunnel

### Complex Variable Types

**Proxmox Connection** (object):
```hcl
variable "proxmox" {
  type = object({
    endpoint = string
    node     = string
    insecure = bool
    ssh_user = string
    ssh_port = optional(number, 2222)
  })
}
```

**Proxmox Authentication** (object, sensitive):
```hcl
variable "proxmox_auth" {
  type = object({
    api_token = string
  })
  sensitive = true
}
```

**K3s Defaults** (nested object):
```hcl
variable "k3s_defaults" {
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

**K3s VMs Map** (map of objects, keyed `<role>_<NN>`; validated against `k3s_roles` ranges and `proxmox_nodes`):
```hcl
variable "k3s_vms" {
  type = map(object({
    node_name = string
    cores     = optional(number) # defaults to the role's cores
    memory    = optional(number) # defaults to the role's memory
  }))
}
```
`local.k3s_vms` in `main.tf` expands each entry to `role`, `name`, `vm_id`, `ip_address`, `node_name`, `cores` and `memory` for the module.

**Usage in resources** (`modules/k3s_cluster/main.tf`, inputs passed from `module "k3s_cluster"` in `main.tf`):
```hcl
resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  for_each = var.cluster_nodes # local.k3s_vms

  name      = each.value.name
  node_name = each.value.node_name # clones the template on this node
  migrate   = true                  # node change migrates, clone is in ignore_changes
  vm_id     = each.value.vm_id

  disk {
    datastore_id = var.storage_pool           # local.storage_pool
    interface    = var.default_disk_interface # var.k3s_defaults.disk_interface
    size         = var.default_disk_size      # var.k3s_defaults.disk_size
  }

  initialization {
    ip_config {
      ipv4 {
        address = local.vm_ip_configs[each.key]
        gateway = var.network_gateway # var.network.gateway
      }
    }
    user_account {
      username = var.cloudinit_username # var.vm_cloudinit.username
      password = var.cloudinit_password # var.vm_cloudinit.password
      keys     = var.cloudinit_ssh_key != "" ? [var.cloudinit_ssh_key] : []
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
❌ **Not using `tofu plan` before `apply`**
❌ **Committing `terraform.tfvars` to version control (contains secrets)**

## OpenTofu Best Practices

### State Management
- State is remote in Cloudflare R2 (`backend.tf`), locked with `use_lockfile = true`. See README for the `.envrc` setup.
- Never commit `terraform.tfvars` (contains credentials)
- Keep state file secure (contains IP addresses, VM IDs)

### Workflow
1. Edit variables or resources
2. Run `tofu fmt` to format
3. Run `tofu validate` to check syntax
4. Run `tofu plan` to preview changes
5. Review plan output carefully
6. Run `tofu apply` to implement
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
- Increase `k3s_defaults.qemu_agent.timeout`

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
6. Test changes with `tofu plan` and NEVER run apply
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

- [bpg Proxmox Provider Docs](https://search.opentofu.org/provider/bpg/proxmox/latest)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)

## Safeguards
1. Always check if a value should be a variable
2. Always try to use existing variables rather than creating new ones
3. Always maintain DRY principles
4. Always keep comments simple and clean
5. Test changes with `tofu plan` before committing
6. NEVER run tofu apply
7. NEVER run tofu destroy
8. NEVER run tofu destroy -auto-approve
