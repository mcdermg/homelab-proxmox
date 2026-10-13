# OpenTofu Proxmox Homelab

OpenTofu + Ansible configuration for Proxmox VE homelab infrastructure including K3s cluster, LXC containers, and Cloudflare Tunnel.

## Infrastructure

**LXC Containers (TurnKey Linux, except Caddy on Alpine and the plain Debian 13 ones):**
- LibreSpeed (CT 111) - Speed test (`librespeed/speedtest-rust`), Debian 13
- Pulse (CT 112) - Proxmox cluster monitoring, Debian 13. Login: `admin` / `tofu output -raw pulse_admin_password`
- Cloudflared (CT 113) - Cloudflare Tunnel client
- Caddy (CT 114) - Reverse proxy (not configured yet)
- Bind9 (CT 115) - DNS server
- Postgres (CT 116) - Database server
- Gitea (CT 117) - Git server

**K3s Cluster:**
- 2 control plane VMs (Proxmox VMs 210-211)
- 2 worker VMs (Proxmox VMs 215-216)
- 2 Raspberry Pi nodes (external hardware, Pi 4 `.241` and Pi 3 `.242`)

**Services:**
- Cloudflare Zero Trust Tunnel with automatic DNS records
- Internal DNS via Bind9
- SSH keys are injected into containers and VMs, but the generated Ansible inventory still logs in with passwords for LXCs and k3s VMs

## Ansible Operations

**Initial Bootstrap:** `ansible/playbook.yaml`
- Configures TurnKey containers via Proxmox `pct` commands
- Sets up SSH keys and root passwords via inithooks
- Installs and configures services (Bind9, Postgres, Gitea, Cloudflared)

**System Updates:** `ansible/update.yaml`
- Updates Proxmox host, all LXC containers, and K3s nodes
- Runs in batches of 4 to avoid resource bottleneck
- Use `--limit` to target specific groups or hosts

```bash
ansible-playbook update.yaml                    # Update everything
ansible-playbook update.yaml --limit proxmox    # Proxmox only
ansible-playbook update.yaml --limit k3s_pis    # Raspberry Pis only
```

## Networking

### Lab IP Layout
Layout for `192.168.1.0/24`. The DHCP pool and static leases are managed in [mikrotik-hapac2](https://github.com/mcdermg/mikrotik-hapac2).

| Range | Use |
|---|---|
| `.1` | MikroTik |
| `.2`–`.9` | Network gear (spare) |
| `.10`–`.49` | k8s LoadBalancer pool (MetalLB) |
| `.50`–`.99` | DHCP pool |
| `.100`–`.199` | LXCs (VMID = last octet) |
| `.200`–`.239` | k3s VMs (VMID = last octet) |
| `.240`–`.248` | Pis and other physical hosts (Pi 4 `.241`, Pi 3 `.242`) |
| `.249` | MikroTik ISP monitor container |
| `.250`–`.252` | Proxmox nodes (pve01 `.250`, pve02 `.251`, spare `.252`) |
| `.253` | Proxmox QDevice (reserved) |
| `.254` | TP-Link switch |

### Routes

Route not set, device dependednt and will need to run:

```
sudo ip route del 192.168.1.0/24 via 192.168.0.1 dev enx98e743f1296c
sudo ip route del 192.168.1.0/24 via 192.168.0.1 dev wlp59s0
```

Added a static route already via:

```
sudo nmcli connection modify "Wired connection 1" +ipv4.routes "192.168.1.0/24 192.168.0.98"
sudo nmcli connection up "Wired connection 1"

sudo nmcli connection modify "WIFI_SSID" +ipv4.routes "192.168.1.0/24 192.168.0.98"
sudo nmcli connection up "WIFI_SSID"
```

## Cluster Connectivity

pve01 and pve02 form one Proxmox cluster. OpenTofu reaches both through two connections, both configured in the `provider "proxmox"` block in `versions.tf`.

### API: one endpoint for the cluster

```
tofu ──HTTPS + API token──► pve01:8006 (proxmox.endpoint)
                               │
                               └── request for /nodes/pve02/... is forwarded ──► pve02
```

- `proxmox.endpoint` and `proxmox_auth.api_token` in `terraform.tfvars` point at pve01 only.
- Proxmox forwards any API request for another cluster node to that node ([pveproxy](https://pve.proxmox.com/pve-docs/pveproxy.8.html)), so pve02 needs no endpoint or token of its own. API users and tokens are cluster-wide.
- If pve01 is down, OpenTofu can't manage either node.

### SSH: one entry per node

The provider uses SSH for the few operations the API can't do, such as file uploads. The `ssh` block creates one `node {}` entry per node in `var.proxmox_nodes`, using its `address`, `proxmox.ssh_port` (2222) and `proxmox.ssh_user`, with keys from the SSH agent.

### Which node a resource lands on

Connecting to the cluster and placing a resource on a node are separate. Each resource names its own node:

| Resource | Node setting | Lands on |
|---|---|---|
| `module.proxmox_node` (APT repos, ZFS pool) | each key of `var.proxmox_nodes` | pve01 and pve02 |
| `proxmox_storage_zfspool.nvme_storage` | `nodes = keys(var.proxmox_nodes)` | cluster-wide entry for both |
| Download modules | each key of `var.proxmox_nodes` | pve01 and pve02 (`nvme-files` is local to each node) |
| `k3s_cluster`, `lxc_containers` | `proxmox.node` in `terraform.tfvars` | pve01 |

### Where the node details live

- `terraform.tfvars`: the `proxmox` block (endpoint, default guest node, SSH user and port) and `proxmox_auth`. Only pve01's details are needed here.
- `variables.tf`: the `proxmox_nodes` default lists every node with its SSH address and ZFS pool disks. Adding a node to the cluster starts here.

## State Backend (Cloudflare R2)

State is stored remotely in a Cloudflare R2 bucket via OpenTofu's S3-compatible backend (`backend.tf`):

- **Bucket:** `iac-state`
- **Key:** `homelab/proxmox/terraform.tfstate`
- **Locking:** native S3 lockfile (`use_lockfile = true`), no DynamoDB needed
- **Region:** `auto` with AWS-specific validation checks skipped, as R2 is not AWS

Credentials and the R2 endpoint are not in `backend.tf`. They are supplied as environment variables from a local, gitignored `.envrc` loaded by [direnv](https://direnv.net/):

```bash
#!/usr/bin/env bash
export AWS_ACCESS_KEY_ID="<r2-access-key-id>"
export AWS_SECRET_ACCESS_KEY="<r2-secret-access-key>"
export AWS_ENDPOINT_URL_S3="https://<cloudflare-account-id>.r2.cloudflarestorage.com"
```

Create an R2 API token with Object Read & Write on the `iac-state` bucket, fill in `.envrc`, then:

```bash
direnv allow
tofu init
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.27 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.0 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.116 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.6 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.27.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.6.2 |
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.1 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.116.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.9.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_iso_downloads"></a> [iso\_downloads](#module\_iso\_downloads) | ./modules/download_file | n/a |
| <a name="module_k3s_cluster"></a> [k3s\_cluster](#module\_k3s\_cluster) | ./modules/k3s_cluster | n/a |
| <a name="module_lxc_containers"></a> [lxc\_containers](#module\_lxc\_containers) | ./modules/lxc_container | n/a |
| <a name="module_lxc_template_downloads"></a> [lxc\_template\_downloads](#module\_lxc\_template\_downloads) | ./modules/download_file | n/a |
| <a name="module_proxmox_node"></a> [proxmox\_node](#module\_proxmox\_node) | ./modules/proxmox_node | n/a |
| <a name="module_tunnel_dns_records"></a> [tunnel\_dns\_records](#module\_tunnel\_dns\_records) | ./modules/cloudflare_dns | n/a |
| <a name="module_vm_image_downloads"></a> [vm\_image\_downloads](#module\_vm\_image\_downloads) | ./modules/download_file | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_zero_trust_access_application.tunnel_services](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_access_application) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_config.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config) | resource |
| [local_file.ansible_hosts_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.gitea_init_script](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.postgres_init_script](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [proxmox_acl.pulse_token](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl) | resource |
| [proxmox_acl.pulse_user](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/acl) | resource |
| [proxmox_storage_directory.nvme_files](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/storage_directory) | resource |
| [proxmox_storage_zfspool.nvme_storage](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/storage_zfspool) | resource |
| [proxmox_user_token.pulse_monitor](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/user_token) | resource |
| [proxmox_virtual_environment_role.pulse_monitor](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_role) | resource |
| [proxmox_virtual_environment_user.pulse_monitor](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_user) | resource |
| [random_id.cloudflared_tunnel_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_password.pulse_admin](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.pulse_api_token](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [cloudflare_zero_trust_tunnel_cloudflared_token.homelab](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zero_trust_tunnel_cloudflared_token) | data source |
| [http_http.my_ipv4](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.my_ipv6](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apt_repositories"></a> [apt\_repositories](#input\_apt\_repositories) | APT standard repository handles to enable or disable on every Proxmox node | <pre>object({<br/>    enabled  = list(string)<br/>    disabled = list(string)<br/>  })</pre> | <pre>{<br/>  "disabled": [<br/>    "enterprise",<br/>    "ceph-squid-enterprise"<br/>  ],<br/>  "enabled": [<br/>    "no-subscription"<br/>  ]<br/>}</pre> | no |
| <a name="input_cloudflare_account_id"></a> [cloudflare\_account\_id](#input\_cloudflare\_account\_id) | Cloudflare Account ID for tunnel management | `string` | n/a | yes |
| <a name="input_cloudflare_api_token"></a> [cloudflare\_api\_token](#input\_cloudflare\_api\_token) | Cloudflare API token for managing DNS and tunnels | `string` | n/a | yes |
| <a name="input_cloudflare_zone"></a> [cloudflare\_zone](#input\_cloudflare\_zone) | Cloudflare zone/domain name | `string` | n/a | yes |
| <a name="input_cloudflare_zone_id"></a> [cloudflare\_zone\_id](#input\_cloudflare\_zone\_id) | Cloudflare Zone ID for the domain | `string` | n/a | yes |
| <a name="input_gitea_admin_password"></a> [gitea\_admin\_password](#input\_gitea\_admin\_password) | Password for Gitea admin user | `string` | n/a | yes |
| <a name="input_gitea_db_password"></a> [gitea\_db\_password](#input\_gitea\_db\_password) | Password for Gitea PostgreSQL database user | `string` | n/a | yes |
| <a name="input_iso_downloads"></a> [iso\_downloads](#input\_iso\_downloads) | ISO files to download to Proxmox storage | <pre>map(object({<br/>    url                     = string<br/>    file_name               = optional(string)<br/>    checksum                = optional(string)<br/>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br/>    decompression_algorithm = optional(string)<br/>    verify                  = optional(bool, true)<br/>    overwrite               = optional(bool, true)<br/>    overwrite_unmanaged     = optional(bool, false)<br/>    upload_timeout          = optional(number, 1800)<br/>  }))</pre> | `{}` | no |
| <a name="input_k3s_defaults"></a> [k3s\_defaults](#input\_k3s\_defaults) | Default configuration for K3s VMs | <pre>object({<br/>    disk_interface = string<br/>    disk_size      = number<br/>    qemu_agent = object({<br/>      enabled = bool<br/>      timeout = string<br/>    })<br/>    behavior = object({<br/>      on_boot         = bool<br/>      started         = bool<br/>      stop_on_destroy = bool<br/>    })<br/>  })</pre> | <pre>{<br/>  "behavior": {<br/>    "on_boot": true,<br/>    "started": true,<br/>    "stop_on_destroy": true<br/>  },<br/>  "disk_interface": "scsi0",<br/>  "disk_size": 17,<br/>  "qemu_agent": {<br/>    "enabled": false,<br/>    "timeout": "4m"<br/>  }<br/>}</pre> | no |
| <a name="input_k3s_pi_01_ip"></a> [k3s\_pi\_01\_ip](#input\_k3s\_pi\_01\_ip) | IP address for K3s Raspberry Pi control node 01 | `string` | n/a | yes |
| <a name="input_k3s_pi_02_ip"></a> [k3s\_pi\_02\_ip](#input\_k3s\_pi\_02\_ip) | IP address for K3s Raspberry Pi worker node 01 | `string` | n/a | yes |
| <a name="input_k3s_vms"></a> [k3s\_vms](#input\_k3s\_vms) | K3s cluster VM specifications | <pre>map(object({<br/>    vm_id      = number<br/>    name       = string<br/>    cores      = number<br/>    memory     = number<br/>    ip_address = string<br/>    role       = string<br/>  }))</pre> | <pre>{<br/>  "control_01": {<br/>    "cores": 2,<br/>    "ip_address": "192.168.1.210",<br/>    "memory": 2048,<br/>    "name": "k3s-control-tf-01",<br/>    "role": "control",<br/>    "vm_id": 210<br/>  },<br/>  "control_02": {<br/>    "cores": 2,<br/>    "ip_address": "192.168.1.211",<br/>    "memory": 2048,<br/>    "name": "k3s-control-tf-02",<br/>    "role": "control",<br/>    "vm_id": 211<br/>  },<br/>  "worker_01": {<br/>    "cores": 2,<br/>    "ip_address": "192.168.1.215",<br/>    "memory": 2048,<br/>    "name": "k3s-node-tf-01",<br/>    "role": "node",<br/>    "vm_id": 215<br/>  },<br/>  "worker_02": {<br/>    "cores": 2,<br/>    "ip_address": "192.168.1.216",<br/>    "memory": 2048,<br/>    "name": "k3s-node-tf-02",<br/>    "role": "node",<br/>    "vm_id": 216<br/>  }<br/>}</pre> | no |
| <a name="input_lxc_containers"></a> [lxc\_containers](#input\_lxc\_containers) | LXC container specifications | <pre>map(object({<br/>    vm_id            = number<br/>    name             = string<br/>    template_file_id = string<br/>    os_type          = optional(string, "debian")<br/><br/>    # Resources<br/>    cores     = optional(number, 1)<br/>    cpu_units = optional(number, 1024)<br/>    memory    = optional(number, 512)<br/>    swap      = optional(number, 0)<br/>    disk_size = optional(number, 8)<br/><br/>    # Network<br/>    ip_address = string # Main IP address for the container<br/><br/>    # Optional advanced configuration<br/>    description  = optional(string)<br/>    unprivileged = optional(bool, true)<br/><br/>    # Features for special use cases<br/>    features = optional(object({<br/>      nesting = optional(bool, false) # Enable for Docker/nested containers<br/>      keyctl  = optional(bool, false) # Enable for systemd<br/>      fuse    = optional(bool, false)<br/>      mount   = optional(list(string), [])<br/>    }))<br/><br/>    # Startup configuration<br/>    startup_order = optional(number)<br/>    start_on_boot = optional(bool, true)<br/>    started       = optional(bool, true)<br/><br/>    # Tags (terraform and IP will be auto-added)<br/>    tags = optional(list(string), [])<br/>  }))</pre> | <pre>{<br/>  "bind9": {<br/>    "cores": 2,<br/>    "disk_size": 10,<br/>    "features": {<br/>      "nesting": true<br/>    },<br/>    "ip_address": "192.168.1.115",<br/>    "memory": 2048,<br/>    "name": "bind9",<br/>    "os_type": "debian",<br/>    "started": false,<br/>    "swap": 512,<br/>    "tags": [<br/>      "turnkey"<br/>    ],<br/>    "template_file_id": "debian-12-turnkey-core_18.1-1_amd64.tar.gz",<br/>    "vm_id": 115<br/>  },<br/>  "caddy": {<br/>    "cores": 1,<br/>    "disk_size": 8,<br/>    "features": {<br/>      "nesting": false<br/>    },<br/>    "ip_address": "192.168.1.114",<br/>    "memory": 1024,<br/>    "name": "caddy",<br/>    "os_type": "alpine",<br/>    "started": false,<br/>    "swap": 256,<br/>    "tags": [<br/>      "alpine"<br/>    ],<br/>    "template_file_id": "alpine-3.22-default_20250617_amd64.tar.xz",<br/>    "vm_id": 114<br/>  },<br/>  "cloudflared": {<br/>    "cores": 1,<br/>    "disk_size": 8,<br/>    "features": {<br/>      "nesting": false<br/>    },<br/>    "ip_address": "192.168.1.113",<br/>    "memory": 512,<br/>    "name": "cloudflared",<br/>    "os_type": "debian",<br/>    "started": false,<br/>    "swap": 256,<br/>    "tags": [<br/>      "turnkey"<br/>    ],<br/>    "template_file_id": "debian-12-turnkey-core_18.1-1_amd64.tar.gz",<br/>    "vm_id": 113<br/>  },<br/>  "gitea": {<br/>    "cores": 2,<br/>    "disk_size": 10,<br/>    "features": {<br/>      "nesting": true<br/>    },<br/>    "ip_address": "192.168.1.117",<br/>    "memory": 2048,<br/>    "name": "gitea",<br/>    "os_type": "debian",<br/>    "started": false,<br/>    "swap": 512,<br/>    "tags": [<br/>      "turnkey"<br/>    ],<br/>    "template_file_id": "debian-12-turnkey-gitea_18.0-1_amd64.tar.gz",<br/>    "vm_id": 117<br/>  },<br/>  "librespeed": {<br/>    "cores": 1,<br/>    "disk_size": 4,<br/>    "features": {<br/>      "nesting": true<br/>    },<br/>    "ip_address": "192.168.1.111",<br/>    "memory": 512,<br/>    "name": "librespeed",<br/>    "os_type": "debian",<br/>    "swap": 256,<br/>    "tags": [<br/>      "debian"<br/>    ],<br/>    "template_file_id": "debian-13-standard_13.1-2_amd64.tar.zst",<br/>    "vm_id": 111<br/>  },<br/>  "postgres": {<br/>    "cores": 2,<br/>    "disk_size": 10,<br/>    "features": {<br/>      "nesting": true<br/>    },<br/>    "ip_address": "192.168.1.116",<br/>    "memory": 2048,<br/>    "name": "postgres",<br/>    "os_type": "debian",<br/>    "started": false,<br/>    "swap": 512,<br/>    "tags": [<br/>      "turnkey"<br/>    ],<br/>    "template_file_id": "debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz",<br/>    "vm_id": 116<br/>  },<br/>  "pulse": {<br/>    "cores": 1,<br/>    "disk_size": 8,<br/>    "features": {<br/>      "nesting": true<br/>    },<br/>    "ip_address": "192.168.1.112",<br/>    "memory": 1024,<br/>    "name": "pulse",<br/>    "os_type": "debian",<br/>    "swap": 256,<br/>    "tags": [<br/>      "debian",<br/>      "monitoring"<br/>    ],<br/>    "template_file_id": "debian-13-standard_13.1-2_amd64.tar.zst",<br/>    "vm_id": 112<br/>  }<br/>}</pre> | no |
| <a name="input_lxc_defaults"></a> [lxc\_defaults](#input\_lxc\_defaults) | Default configuration for LXC containers | <pre>object({<br/>    password       = string<br/>    ssh_public_key = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_lxc_template_downloads"></a> [lxc\_template\_downloads](#input\_lxc\_template\_downloads) | LXC container templates to download to Proxmox storage | <pre>map(object({<br/>    url                     = string<br/>    file_name               = optional(string)<br/>    checksum                = optional(string)<br/>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br/>    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"<br/>    verify                  = optional(bool, true)<br/>    overwrite               = optional(bool, true)<br/>    overwrite_unmanaged     = optional(bool, false)<br/>    upload_timeout          = optional(number, 1800)<br/>  }))</pre> | <pre>{<br/>  "alpine_322": {<br/>    "url": "http://download.proxmox.com/images/system/alpine-3.22-default_20250617_amd64.tar.xz"<br/>  },<br/>  "debian_13": {<br/>    "url": "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"<br/>  },<br/>  "turnkey_debian_12_core": {<br/>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-core_18.1-1_amd64.tar.gz"<br/>  },<br/>  "turnkey_debian_12_gitea": {<br/>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-gitea_18.0-1_amd64.tar.gz"<br/>  },<br/>  "turnkey_debian_12_postgresql": {<br/>    "url": "http://mirror.turnkeylinux.org/turnkeylinux/images/proxmox/debian-12-turnkey-postgresql_18.1-1_amd64.tar.gz"<br/>  }<br/>}</pre> | no |
| <a name="input_network"></a> [network](#input\_network) | Network configuration for VMs | <pre>object({<br/>    gateway     = string<br/>    cidr_suffix = string<br/>  })</pre> | <pre>{<br/>  "cidr_suffix": "/24",<br/>  "gateway": "192.168.1.1"<br/>}</pre> | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Network bridge to use for VMs | `string` | `"vmbr0"` | no |
| <a name="input_proxmox"></a> [proxmox](#input\_proxmox) | Proxmox connection configuration | <pre>object({<br/>    endpoint = string<br/>    node     = string<br/>    insecure = bool<br/>    ssh_user = string<br/>    ssh_port = optional(number, 2222)<br/>  })</pre> | n/a | yes |
| <a name="input_proxmox_auth"></a> [proxmox\_auth](#input\_proxmox\_auth) | Proxmox authentication credentials | <pre>object({<br/>    api_token = string<br/>  })</pre> | n/a | yes |
| <a name="input_proxmox_nodes"></a> [proxmox\_nodes](#input\_proxmox\_nodes) | Proxmox nodes: SSH address, the disks for each node's ZFS storage pool, and the VM ID of its k3s template | <pre>map(object({<br/>    address        = string<br/>    template_vm_id = number<br/>    zfs_pool = object({<br/>      devices   = list(string)<br/>      raidlevel = optional(string, "single")<br/>    })<br/>  }))</pre> | <pre>{<br/>  "pve01": {<br/>    "address": "192.168.1.250",<br/>    "template_vm_id": 9000,<br/>    "zfs_pool": {<br/>      "devices": [<br/>        "/dev/disk/by-id/nvme-CA3-8D512-Q11_NVMe_LITEON_512GB_TW092X04LOH009BQ0115"<br/>      ]<br/>    }<br/>  },<br/>  "pve02": {<br/>    "address": "192.168.1.251",<br/>    "template_vm_id": 9001,<br/>    "zfs_pool": {<br/>      "devices": [<br/>        "/dev/disk/by-id/nvme-Micron_2200S_NVMe_512GB__194725011C72"<br/>      ]<br/>    }<br/>  }<br/>}</pre> | no |
| <a name="input_vm_cloudinit"></a> [vm\_cloudinit](#input\_vm\_cloudinit) | Cloud-init configuration for VMs | <pre>object({<br/>    username       = string<br/>    password       = string<br/>    ssh_public_key = optional(string, "")<br/>  })</pre> | n/a | yes |
| <a name="input_vm_image_downloads"></a> [vm\_image\_downloads](#input\_vm\_image\_downloads) | VM disk images to download to Proxmox storage | <pre>map(object({<br/>    url                     = string<br/>    file_name               = optional(string)<br/>    checksum                = optional(string)<br/>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br/>    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2"<br/>    verify                  = optional(bool, true)<br/>    overwrite               = optional(bool, true)<br/>    overwrite_unmanaged     = optional(bool, false)<br/>    upload_timeout          = optional(number, 1800)<br/>  }))</pre> | <pre>{<br/>  "debian_13_generic": {<br/>    "checksum": "6f0f93335bdef4ccf523c4317cc663ea52ca23b862667785f3d6d186ab4674a937385ccff0c55996b4b2e4c19e440cdf211e2a75ffa2f6548037ab43950c841d",<br/>    "checksum_algorithm": "sha512",<br/>    "url": "https://cloud.debian.org/images/cloud/trixie/20261001-2618/debian-13-generic-amd64-20261001-2618.qcow2"<br/>  }<br/>}</pre> | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_pulse_admin_password"></a> [pulse\_admin\_password](#output\_pulse\_admin\_password) | Pulse web UI password for the admin user (tofu output -raw pulse\_admin\_password) |
<!-- END_TF_DOCS -->
