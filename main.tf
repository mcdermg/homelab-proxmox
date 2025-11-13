locals {
  # Have been playing with storage so leaving these here for now and can move to vars later
  datastore_id = "nvme-files"   # NVMe ZFS pool for ISOs/templates (file storage)
  storage_pool = "nvme-storage" # NVMe ZFS pool for VM/container disks
}

# DOWNLOADS
module "lxc_template_downloads" {
  source = "./modules/download_file"

  node_name    = var.node_name
  datastore_id = local.datastore_id
  downloads    = var.lxc_template_downloads
  content_type = "vztmpl"
}

module "iso_downloads" {
  source = "./modules/download_file"

  node_name    = var.node_name
  datastore_id = local.datastore_id
  downloads    = var.iso_downloads
  content_type = "iso"

  depends_on = [
    module.lxc_template_downloads,
  ]
}

module "vm_image_downloads" {
  source = "./modules/download_file"

  node_name    = var.node_name
  datastore_id = local.datastore_id
  downloads    = var.vm_image_downloads
  content_type = "import"

  depends_on = [
    module.iso_downloads,
  ]
}

# K3S CLUSTER
module "k3s_cluster" {
  source = "./modules/k3s_cluster"

  cluster_nodes = var.k3s_vms

  # Proxmox settings
  proxmox_node   = var.proxmox.node
  template_vm_id = var.k3s_template_vm_id
  storage_pool   = local.storage_pool

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
  cloudinit_ssh_key  = var.vm_cloudinit.ssh_public_key

  depends_on = [
    module.vm_image_downloads, # doesn't really but just for not doing everything at once
  ]
}

# LXC CONTAINERS
module "lxc_containers" {
  source = "./modules/lxc_container"

  proxmox_node    = var.proxmox.node
  storage_pool    = local.storage_pool
  network_bridge  = var.network_bridge
  network_gateway = var.network.gateway

  default_ssh_keys = var.lxc_defaults.ssh_public_key != "" ? [var.lxc_defaults.ssh_public_key] : []
  default_password = var.lxc_defaults.password

  containers = {
    for key, container in var.lxc_containers : key => {
      vm_id            = container.vm_id
      name             = container.name
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
    module.k3s_cluster,
  ]
}

resource "local_file" "ansible_hosts_file" {
  count = contains(keys(var.lxc_containers), "postgres") && contains(keys(var.lxc_containers), "gitea") ? 1 : 0

  content = templatefile("${path.module}/templates/ansible_hosts.ini.tftpl", {
    # Proxmox host connection details
    proxmox_node         = var.proxmox.node
    proxmox_host         = replace(replace(var.proxmox.endpoint, "https://", ""), ":8006", "")
    proxmox_ssh_user     = var.proxmox.ssh_user
    proxmox_ssh_port     = var.proxmox.ssh_port
    proxmox_api_user     = var.proxmox_auth.username
    proxmox_api_password = var.proxmox_auth.password

    # Container details for pct operations
    postgres_ctid    = var.lxc_containers.postgres.vm_id
    postgres_ip      = var.lxc_containers.postgres.ip_address
    gitea_ctid       = var.lxc_containers.gitea.vm_id
    gitea_ip         = var.lxc_containers.gitea.ip_address
    bind9_ctid       = var.lxc_containers.bind9.vm_id
    bind9_ip         = var.lxc_containers.bind9.ip_address
    cloudflared_ctid = var.lxc_containers.cloudflared.vm_id
    cloudflared_ip   = var.lxc_containers.cloudflared.ip_address

    # Cloudflare Tunnel
    cloudflare_tunnel_id    = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
    cloudflare_tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token

    # LXC defaults
    lxc_root_password = var.lxc_defaults.password
  })
  filename = "${path.module}/ansible/hosts.ini"
  depends_on = [
    module.lxc_containers,
    cloudflare_zero_trust_tunnel_cloudflared.homelab,
    data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab,
  ]
}
