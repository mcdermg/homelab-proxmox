# VM IDENTIFICATION OUTPUTS
output "vm_ids" {
  description = "Map of VM names to their VM IDs"
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => vm.vm_id
  }
}

output "vm_names" {
  description = "List of all VM names"
  value = [
    for vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name
  ]
}

# NETWORK OUTPUTS
output "vm_ip_addresses" {
  description = "Map of VM names to their IP addresses"
  value = {
    for key, vm in var.cluster_nodes :
    vm.name => vm.ip_address
  }
}

output "vm_network_details" {
  description = "Complete network configuration for all VMs"
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => {
      vm_id      = vm.vm_id
      ip_address = var.cluster_nodes[key].ip_address
      gateway    = var.network_gateway
      role       = var.cluster_nodes[key].role
    }
  }
}

# ROLE-BASED OUTPUTS
output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value = [
    for key, vm in var.cluster_nodes :
    vm.ip_address if vm.role == "control"
  ]
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value = [
    for key, vm in var.cluster_nodes :
    vm.ip_address if vm.role == "worker"
  ]
}

# ANSIBLE INVENTORY OUTPUTS
output "ansible_inventory_json" {
  description = "Ansible inventory in JSON format"
  sensitive   = true
  value = jsonencode({
    k3s_control = {
      hosts = {
        for key, vm in var.cluster_nodes :
        vm.name => {
          ansible_host = vm.ip_address
          ansible_user = var.cloudinit_username
        } if vm.role == "control"
      }
    }
    k3s_workers = {
      hosts = {
        for key, vm in var.cluster_nodes :
        vm.name => {
          ansible_host = vm.ip_address
          ansible_user = var.cloudinit_username
        } if vm.role == "worker"
      }
    }
  })
}

output "ansible_inventory_ini" {
  description = "Ansible inventory in INI format"
  sensitive   = true
  value       = <<-EOT
[k3s_control]
%{for key, vm in var.cluster_nodes~}
%{if vm.role == "control"~}
${vm.name} ansible_host=${vm.ip_address}
%{endif~}
%{endfor~}

[k3s_workers]
%{for key, vm in var.cluster_nodes~}
%{if vm.role == "worker"~}
${vm.name} ansible_host=${vm.ip_address}
%{endif~}
%{endfor~}

[k3s:children]
k3s_control
k3s_workers

[k3s:vars]
ansible_connection=ssh
ansible_python_interpreter='/usr/bin/python3'
ansible_user=${var.cloudinit_username}
ansible_password=${var.cloudinit_password}
EOT
}

# CONFIGURATION SUMMARY
output "cluster_summary" {
  description = "High-level cluster configuration summary"
  value = {
    total_vms       = length(var.cluster_nodes)
    control_nodes   = length([for vm in var.cluster_nodes : vm if vm.role == "control"])
    worker_nodes    = length([for vm in var.cluster_nodes : vm if vm.role == "worker"])
    network_gateway = var.network_gateway
    storage_pool    = var.storage_pool
    template_id     = var.template_vm_id
  }
}

# VM RESOURCE DETAILS
output "vm_mac_addresses" {
  description = "MAC addresses of VM network interfaces"
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => vm.mac_addresses
  }
}

output "vm_ipv4_addresses" {
  description = "IPv4 addresses reported by QEMU agent"
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => vm.ipv4_addresses
  }
  depends_on = [
    proxmox_virtual_environment_vm.k3s_nodes
  ]
}

# RAW VM RESOURCES
output "vm_resources" {
  description = "Raw VM resource objects for advanced use cases"
  value       = proxmox_virtual_environment_vm.k3s_nodes
}
