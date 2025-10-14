locals {
  # Construct full IP addresses with CIDR
  vm_ip_configs = {
    for key, vm in var.k3s_vms :
    key => "${vm.ip_address}${var.network.cidr_suffix}"
  }
}

# K3S CLUSTER VMS
resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  for_each = var.k3s_vms

  name        = each.value.name
  description = "K3s ${each.value.role} node - Managed by Terraform"
  tags        = ["terraform", "k3s", each.value.role]

  node_name = var.proxmox.node
  vm_id     = each.value.vm_id

  on_boot = var.vm_defaults.behavior.on_boot
  started = var.vm_defaults.behavior.started

  stop_on_destroy = var.vm_defaults.behavior.stop_on_destroy

  # CLONE FROM TEMPLATE
  clone {
    vm_id = var.proxmox_infrastructure.template_vm_id
    full  = true
  }

  # CPU CONFIGURATION
  cpu {
    cores = each.value.cores
    type  = "host"
  }

  # MEMORY CONFIGURATION
  memory {
    dedicated = each.value.memory
  }

  # QEMU GUEST AGENT
  agent {
    enabled = var.vm_defaults.qemu_agent.enabled
    timeout = var.vm_defaults.qemu_agent.timeout
  }

  # DISK CONFIGURATION
  disk {
    datastore_id = var.proxmox_infrastructure.storage_pool
    interface    = var.vm_defaults.disk_interface
    size         = var.vm_defaults.disk_size
    file_format  = "raw"
  }

  # NETWORK CONFIGURATION
  network_device {
    bridge = var.proxmox_infrastructure.network_bridge
  }

  # CLOUD-INIT CONFIGURATION
  initialization {
    datastore_id = var.proxmox_infrastructure.storage_pool

    ip_config {
      ipv4 {
        address = local.vm_ip_configs[each.key]
        gateway = var.network.gateway
      }
    }

    user_account {
      username = var.vm_cloudinit.username
      password = var.vm_cloudinit.password
      keys     = [var.vm_cloudinit.ssh_public_key]
    }
  }

  # LIFECYCLE MANAGEMENT
  lifecycle {
    ignore_changes = [
      # Ignore changes to these attributes to prevent unnecessary updates
      started,
    ]
  }
}

