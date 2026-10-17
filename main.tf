locals {
  # Have been playing with storage so leaving these here for now and can move to vars later
  datastore_id = "nvme-files"   # Directory storage on the nvme-storage pool for ISOs/templates
  storage_pool = "nvme-storage" # NVMe ZFS pool for VM/container disks and template 9000

  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_file)))

  # k3s VMs: the role and number come from the key (worker_03), the VM ID and IP from the role's ID range
  k3s_vm_roles = { for key in keys(var.k3s_vms) : key => split("_", key)[0] }
  k3s_vm_ids = {
    for key, role in local.k3s_vm_roles :
    key => var.k3s_roles[role].first_id + tonumber(split("_", key)[1]) - 1
  }
  k3s_vms = {
    for key, vm in var.k3s_vms : key => {
      role       = local.k3s_vm_roles[key]
      name       = "k3s-${replace(key, "_", "-")}" # worker_03 -> k3s-worker-03
      vm_id      = local.k3s_vm_ids[key]
      ip_address = cidrhost("${var.network.gateway}${var.network.cidr_suffix}", local.k3s_vm_ids[key])
      node_name  = vm.node_name
      cores      = coalesce(vm.cores, var.k3s_roles[local.k3s_vm_roles[key]].cores)
      memory     = coalesce(vm.memory, var.k3s_roles[local.k3s_vm_roles[key]].memory)
    }
  }

  # Internal DNS (bind9, homelab.local): an A and PTR record for every host OpenTofu knows the IP of
  bind9_records = merge(
    { for node, cfg in var.proxmox_nodes : node => cfg.address },
    { for key, ct in var.lxc_containers : ct.name => ct.ip_address },
    { for key, vm in local.k3s_vms : vm.name => vm.ip_address },
    { "pi-control" = var.k3s_pi_01_ip, "pi-worker" = var.k3s_pi_02_ip },
  )
}

# PROXMOX NODES
module "proxmox_node" {
  source   = "./modules/proxmox_node"
  for_each = var.proxmox_nodes

  node_name        = each.key
  apt_repositories = var.apt_repositories
  zfs_pool_name    = local.storage_pool
  zfs_pool         = each.value.zfs_pool
}

# STORAGE
resource "proxmox_storage_zfspool" "nvme_storage" {
  id       = local.storage_pool
  zfs_pool = local.storage_pool
  nodes    = keys(var.proxmox_nodes)
  content  = ["images", "rootdir"]

  # Each node's pool must exist before the cluster-wide entry points at it
  depends_on = [module.proxmox_node]
}

# Directory on each node's pool for ISOs, LXC templates and VM images
# shortcut: the provider can't set is_mountpoint, so if a pool fails to mount Proxmox writes to the root disk instead; set it once the provider supports it
resource "proxmox_storage_directory" "nvme_files" {
  id               = local.datastore_id
  path             = "/${local.storage_pool}/files"
  nodes            = keys(var.proxmox_nodes)
  content          = ["iso", "vztmpl", "import"]
  create_base_path = true

  depends_on = [module.proxmox_node]
}

# DOWNLOADS
# nvme-files is local to each node, so every node gets its own copy
module "lxc_template_downloads" {
  source   = "./modules/download_file"
  for_each = var.proxmox_nodes

  node_name    = each.key
  datastore_id = proxmox_storage_directory.nvme_files.id
  downloads    = var.lxc_template_downloads
  content_type = "vztmpl"
}

module "iso_downloads" {
  source   = "./modules/download_file"
  for_each = var.proxmox_nodes

  node_name    = each.key
  datastore_id = proxmox_storage_directory.nvme_files.id
  downloads    = var.iso_downloads
  content_type = "iso"

  depends_on = [
    module.lxc_template_downloads,
  ]
}

module "vm_image_downloads" {
  source   = "./modules/download_file"
  for_each = var.proxmox_nodes

  node_name    = each.key
  datastore_id = proxmox_storage_directory.nvme_files.id
  downloads    = var.vm_image_downloads
  content_type = "import"

  depends_on = [
    module.iso_downloads,
  ]
}

# K3S CLUSTER
module "k3s_cluster" {
  source = "./modules/k3s_cluster"

  cluster_nodes = local.k3s_vms

  # Proxmox settings
  storage_pool = proxmox_storage_zfspool.nvme_storage.id

  # Templates: one per node, each built from that node's copy of the cloud image
  template_storage_pool = proxmox_storage_zfspool.nvme_storage.id
  templates = {
    for node, cfg in var.proxmox_nodes : node => {
      vm_id         = cfg.template_vm_id
      image_file_id = module.vm_image_downloads[node].file_ids["debian_13_generic"]
    }
  }

  # Network config
  network_bridge      = var.network_bridge
  network_gateway     = var.network.gateway
  network_cidr_suffix = var.network.cidr_suffix

  # VM defaults
  default_disk_interface = var.k3s_defaults.disk_interface
  default_disk_size      = var.k3s_defaults.disk_size
  qemu_agent_enabled     = var.k3s_defaults.qemu_agent.enabled
  qemu_agent_timeout     = var.k3s_defaults.qemu_agent.timeout
  vm_on_boot             = var.k3s_defaults.behavior.on_boot
  vm_started             = var.k3s_defaults.behavior.started
  vm_stop_on_destroy     = var.k3s_defaults.behavior.stop_on_destroy

  # Cloud-init configuration
  cloudinit_username = var.vm_cloudinit.username
  cloudinit_password = var.vm_cloudinit.password
  cloudinit_ssh_key  = local.ssh_public_key

  depends_on = [
    module.vm_image_downloads, # doesn't really but just for not doing everything at once
  ]
}

# LXC CONTAINERS
module "lxc_containers" {
  source = "./modules/lxc_container"

  proxmox_node    = var.proxmox.node # default node for containers without a node_name
  storage_pool    = proxmox_storage_zfspool.nvme_storage.id
  network_bridge  = var.network_bridge
  network_gateway = var.network.gateway

  default_ssh_keys = [local.ssh_public_key]
  default_password = var.lxc_defaults.password

  containers = {
    for key, container in var.lxc_containers : key => {
      vm_id            = container.vm_id
      name             = container.name
      node_name        = container.node_name
      template_file_id = "${local.datastore_id}:vztmpl/${container.template_file_id}"
      os_type          = container.os_type
      cores            = container.cores
      cpu_units        = container.cpu_units
      memory           = container.memory
      swap             = container.swap
      disk_size        = container.disk_size
      description      = container.description
      unprivileged     = container.unprivileged

      network_interfaces = [{
        name = "eth0"
      }]

      ip_configs = [{
        ipv4_address = "${container.ip_address}${var.network.cidr_suffix}"
        ipv4_gateway = var.network.gateway
      }]

      features = container.features

      startup_order = container.startup_order
      start_on_boot = container.start_on_boot
      started       = container.started

      tags = container.tags
    }
  }
  depends_on = [
    module.lxc_template_downloads,
    #module.k3s_cluster,
  ]
}

# PULSE MONITORING ACCESS
# Read-only Proxmox access for Pulse, mirroring the user, token and role Pulse's own install.sh creates
resource "proxmox_virtual_environment_user" "pulse_monitor" {
  user_id = "pulse-monitor@pve"
  comment = "Pulse monitoring (managed by OpenTofu)"
}

resource "proxmox_user_token" "pulse_monitor" {
  user_id               = proxmox_virtual_environment_user.pulse_monitor.user_id
  token_name            = "pulse-readonly"
  privileges_separation = true
  comment               = "Pulse monitoring (managed by OpenTofu)"
}

# VM.GuestAgent.FileRead lets Pulse read VM memory from /proc/meminfo
resource "proxmox_virtual_environment_role" "pulse_monitor" {
  role_id    = "PulseMonitor"
  privileges = ["Sys.Audit", "VM.GuestAgent.Audit", "VM.GuestAgent.FileRead"]
}

# The token has privilege separation, so it needs the same ACLs as the user
resource "proxmox_acl" "pulse_user" {
  for_each = toset(["PVEAuditor", proxmox_virtual_environment_role.pulse_monitor.role_id])

  user_id   = proxmox_virtual_environment_user.pulse_monitor.user_id
  role_id   = each.key
  path      = "/"
  propagate = true
}

resource "proxmox_acl" "pulse_token" {
  for_each = toset(["PVEAuditor", proxmox_virtual_environment_role.pulse_monitor.role_id])

  token_id  = proxmox_user_token.pulse_monitor.id
  role_id   = each.key
  path      = "/"
  propagate = true
}

# Pulse API token, only used by Ansible for the first-time setup
resource "random_password" "pulse_api_token" {
  length  = 48
  special = false
}

resource "local_file" "ansible_hosts_file" {
  count = contains(keys(var.lxc_containers), "postgres") && contains(keys(var.lxc_containers), "gitea") ? 1 : 0

  content = templatefile("${path.module}/templates/ansible_hosts.ini.tftpl", {
    # Proxmox connection details: every node for SSH, pve01's API endpoint for Pulse
    proxmox_nodes    = var.proxmox_nodes
    proxmox_host     = replace(replace(var.proxmox.endpoint, "https://", ""), ":8006", "")
    proxmox_ssh_user = var.proxmox.ssh_user
    proxmox_ssh_port = var.proxmox.ssh_port

    # Container details for pct operations
    lxc_nodes        = { for key, ct in var.lxc_containers : key => coalesce(ct.node_name, var.proxmox.node) }
    postgres_ctid    = var.lxc_containers.postgres.vm_id
    postgres_ip      = var.lxc_containers.postgres.ip_address
    gitea_ctid       = var.lxc_containers.gitea.vm_id
    gitea_ip         = var.lxc_containers.gitea.ip_address
    bind9_ctid       = var.lxc_containers.bind9.vm_id
    bind9_ip         = var.lxc_containers.bind9.ip_address
    cloudflared_ctid = var.lxc_containers.cloudflared.vm_id
    cloudflared_ip   = var.lxc_containers.cloudflared.ip_address

    # Internal DNS records for the bind9 zones, as JSON (Ansible reads it as a dict)
    bind9_records = jsonencode(local.bind9_records)

    # Containers configured over SSH
    librespeed_ip = var.lxc_containers.librespeed.ip_address
    pulse_ip      = var.lxc_containers.pulse.ip_address

    # Slack webhook for lab alerts
    slack_alerting_webhook = var.slack_alerting_webhook

    # Pulse first-time setup
    pulse_admin_password   = var.pulse_admin_password
    pulse_api_token        = random_password.pulse_api_token.result
    pulse_pve_token_id     = proxmox_user_token.pulse_monitor.id
    pulse_pve_token_secret = split("=", proxmox_user_token.pulse_monitor.value)[1]

    # Postgres and Gitea first boot
    postgres_admin_password = var.postgres_admin_password
    gitea_db_password       = var.gitea_db_password
    gitea_admin_password    = var.gitea_admin.password
    gitea_admin_email       = var.gitea_admin.email

    # Cloudflare Tunnel
    cloudflare_tunnel_id    = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
    cloudflare_tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token

    # LXC defaults
    lxc_root_password  = var.lxc_defaults.password
    lxc_ssh_public_key = local.ssh_public_key

    # K3s VMs, grouped by role in the template
    k3s_vms = local.k3s_vms

    # K3s Raspberry Pi IPs
    k3s_pi_01_ip = var.k3s_pi_01_ip
    k3s_pi_02_ip = var.k3s_pi_02_ip

    # VM cloud-init user, Ansible logs in as it with the SSH key
    vm_cloudinit_username = var.vm_cloudinit.username
  })
  filename = "${path.module}/ansible/hosts.ini"
  depends_on = [
    module.lxc_containers,
    cloudflare_zero_trust_tunnel_cloudflared.homelab,
    data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab,
  ]
}
