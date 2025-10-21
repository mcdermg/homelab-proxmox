output "container_ids" {
  description = "Map of container names to their VM IDs"
  value       = { for k, v in proxmox_virtual_environment_container.this : k => v.vm_id }
}

output "container_names" {
  description = "List of all container names"
  value       = [for k, v in proxmox_virtual_environment_container.this : v.initialization[0].hostname]
}

output "container_ip_addresses" {
  description = "Map of container names to their configured IP addresses"
  value = {
    for k, v in proxmox_virtual_environment_container.this : k => try(
      v.initialization[0].ip_config[0].ipv4[0].address,
      null
    )
  }
}

output "container_resources" {
  description = "Raw container resource objects for advanced use cases"
  value       = proxmox_virtual_environment_container.this
}

output "containers" {
  description = "Map of all container details"
  value = {
    for k, v in proxmox_virtual_environment_container.this : k => {
      vm_id      = v.vm_id
      name       = v.initialization[0].hostname
      ip_address = try(v.initialization[0].ip_config[0].ipv4[0].address, null)
      cores      = v.cpu[0].cores
      memory     = v.memory[0].dedicated
      disk_size  = v.disk[0].size
      started    = v.started
      template   = v.template
    }
  }
}

output "container_status" {
  description = "Map of container names to their running status"
  value       = { for k, v in proxmox_virtual_environment_container.this : k => v.started }
}
