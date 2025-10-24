resource "proxmox_virtual_environment_container" "this" {
  for_each = var.containers

  node_name = var.proxmox_node
  vm_id     = each.value.vm_id

  # Container initialization
  description  = try(each.value.description, "Managed by Terraform")
  template     = try(each.value.template, false)
  unprivileged = try(each.value.unprivileged, true)

  # Operating system
  operating_system {
    template_file_id = each.value.template_file_id
    type             = try(each.value.os_type, "debian")
  }

  # CPU configuration
  cpu {
    cores = try(each.value.cores, 1)
    units = try(each.value.cpu_units, 1024)
  }

  # Memory configuration
  memory {
    dedicated = try(each.value.memory, 512)
    swap      = try(each.value.swap, 0)
  }

  # Disk configuration
  disk {
    datastore_id = var.storage_pool
    size         = try(each.value.disk_size, 8)
  }

  # Network configuration
  dynamic "network_interface" {
    for_each = try(each.value.network_interfaces, [])
    content {
      name   = network_interface.value.name
      bridge = try(network_interface.value.bridge, var.network_bridge)

      firewall    = try(network_interface.value.firewall, false)
      enabled     = try(network_interface.value.enabled, true)
      mac_address = try(network_interface.value.mac_address, null)
      rate_limit  = try(network_interface.value.rate_limit, null)
      vlan_id     = try(network_interface.value.vlan_id, null)
    }
  }

  # Initialization
  initialization {
    hostname = each.value.name

    dynamic "ip_config" {
      for_each = try(each.value.ip_configs, [])
      content {
        ipv4 {
          address = try(ip_config.value.ipv4_address, null)
          gateway = try(ip_config.value.ipv4_gateway, var.network_gateway)
        }

        dynamic "ipv6" {
          for_each = try(ip_config.value.ipv6_address, null) != null ? [1] : []
          content {
            address = try(ip_config.value.ipv6_address, null)
            gateway = try(ip_config.value.ipv6_gateway, null)
          }
        }
      }
    }

    user_account {
      keys     = try(each.value.ssh_keys, var.default_ssh_keys)
      password = try(each.value.password, var.default_password)
    }
  }

  # Features
  dynamic "features" {
    for_each = try(each.value.features, null) != null ? [each.value.features] : []
    content {
      fuse    = try(features.value.fuse, false)
      keyctl  = try(features.value.keyctl, false)
      nesting = try(features.value.nesting, false)
      mount   = try(features.value.mount, [])
    }
  }

  # Console configuration
  dynamic "console" {
    for_each = try(each.value.console, null) != null ? [each.value.console] : []
    content {
      enabled   = try(console.value.enabled, true)
      tty_count = try(console.value.tty_count, 2)
      type      = try(console.value.type, "tty")
    }
  }

  # Startup/shutdown order
  dynamic "startup" {
    for_each = (try(each.value.startup_order, null) != null || try(each.value.startup_up_delay, null) != null || try(each.value.startup_down_delay, null) != null) ? [1] : []
    content {
      order      = try(each.value.startup_order, null)
      up_delay   = try(each.value.startup_up_delay, null)
      down_delay = try(each.value.startup_down_delay, null)
    }
  }

  # Container behavior
  start_on_boot = try(each.value.start_on_boot, true)
  started       = try(each.value.started, true)

  # Tags - include terraform and IP address
  tags = concat(
    ["terraform"],
    try(each.value.tags, []),
    [
      for ip_config in try(each.value.ip_configs, []) :
      replace(split("/", try(ip_config.ipv4_address, ""))[0], ".", "-")
      if try(ip_config.ipv4_address, null) != null
    ]
  )

  # Protection
  protection = try(each.value.protection, false)
}
