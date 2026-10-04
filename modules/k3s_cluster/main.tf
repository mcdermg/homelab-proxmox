locals {
  # Construct full IP addresses with CIDR
  vm_ip_configs = {
    for key, vm in var.cluster_nodes :
    key => "${vm.ip_address}${var.network_cidr_suffix}"
  }
}

# K3S VM TEMPLATE
# Mirrors the hand-built template 9000 (Ubuntu 24.04 cloud image), see LAB-16
resource "proxmox_virtual_environment_vm" "template" {
  node_name = var.proxmox_node
  vm_id     = var.template_vm_id

  template = true
  on_boot  = false
  started  = false

  cpu {
    cores = var.template_cores
  }

  memory {
    dedicated = var.template_memory
  }

  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["scsi0"]

  disk {
    datastore_id = var.template_storage_pool
    interface    = "scsi0"
    import_from  = var.template_image_file_id
    size         = 4 # cloud image is 3.5GB, size is whole GB
  }

  # Cloud-init drive only, clones set user, keys and IPs
  initialization {
    datastore_id = var.template_storage_pool
  }

  network_device {
    bridge = var.network_bridge
  }

  serial_device {}

  vga {
    type = "serial0"
  }

  # Only used when creating the template; don't re-import or resize an existing template's base disk
  lifecycle {
    ignore_changes = [
      disk[0].import_from,
      disk[0].size,
    ]
  }
}

# K3S CLUSTER VMS
resource "proxmox_virtual_environment_vm" "k3s_nodes" {
  for_each = var.cluster_nodes

  name        = each.value.name
  description = "K3s ${each.value.role} node - Managed by Terraform"
  tags        = ["terraform", "k3s", each.value.role, replace(each.value.ip_address, ".", "-")]

  node_name = var.proxmox_node
  vm_id     = each.value.vm_id

  on_boot = var.vm_on_boot
  started = var.vm_started

  stop_on_destroy = var.vm_stop_on_destroy

  # CLONE FROM TEMPLATE
  clone {
    vm_id = proxmox_virtual_environment_vm.template.vm_id
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
    enabled = var.qemu_agent_enabled
    timeout = var.qemu_agent_timeout
  }

  # DISK CONFIGURATION
  disk {
    datastore_id = var.storage_pool
    interface    = var.default_disk_interface
    size         = var.default_disk_size
    file_format  = "raw"
  }

  # NETWORK CONFIGURATION
  network_device {
    bridge = var.network_bridge
  }

  # CLOUD-INIT CONFIGURATION
  initialization {
    datastore_id = var.storage_pool

    ip_config {
      ipv4 {
        address = local.vm_ip_configs[each.key]
        gateway = var.network_gateway
      }
    }

    user_account {
      username = var.cloudinit_username
      password = var.cloudinit_password
      keys     = var.cloudinit_ssh_key != "" ? [var.cloudinit_ssh_key] : []
    }
  }

  # LIFECYCLE MANAGEMENT
  lifecycle {
    ignore_changes = [
      # Ignore changes to these attributes to prevent unnecessary updates
      started,
      initialization,
    ]
  }
}
