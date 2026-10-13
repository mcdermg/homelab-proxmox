locals {
  # Construct full IP addresses with CIDR
  vm_ip_configs = {
    for key, vm in var.cluster_nodes :
    key => "${vm.ip_address}${var.network_cidr_suffix}"
  }
}

# K3S VM TEMPLATE
# Mirrors the hand-built template 9000 (LAB-16), now on the Debian 13 generic cloud image (LAB-75)
# One per node: templates on local ZFS can't be cloned to another node (LAB-66)
resource "proxmox_virtual_environment_vm" "template" {
  for_each = var.templates

  node_name = each.key
  vm_id     = each.value.vm_id

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
    import_from  = each.value.image_file_id
    size         = 3 # matches the cloud image's 3GB virtual size
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

  node_name = each.value.node_name
  vm_id     = each.value.vm_id

  # Changing node_name live-migrates the VM instead of recreating it
  migrate = true

  on_boot = var.vm_on_boot
  started = var.vm_started

  stop_on_destroy = var.vm_stop_on_destroy

  # CLONE FROM TEMPLATE
  # The template on the VM's own node
  clone {
    vm_id = proxmox_virtual_environment_vm.template[each.value.node_name].vm_id
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
      # Every clone field forces a new VM; after a migration the template ID differs, so ignore it
      clone,
    ]
  }
}
