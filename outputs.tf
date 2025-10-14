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
    for key, vm in var.k3s_vms :
    vm.name => vm.ip_address
  }
}

output "vm_network_details" {
  description = "Complete network configuration for all VMs"
  value = {
    for key, vm in proxmox_virtual_environment_vm.k3s_nodes :
    vm.name => {
      vm_id      = vm.vm_id
      ip_address = var.k3s_vms[key].ip_address
      gateway    = var.network.gateway
      role       = var.k3s_vms[key].role
    }
  }
}

# ROLE-BASED OUTPUTS
output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value = [
    for key, vm in var.k3s_vms :
    vm.ip_address if vm.role == "control"
  ]
}

output "worker_node_ips" {
  description = "IP addresses of worker nodes"
  value = [
    for key, vm in var.k3s_vms :
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
        for key, vm in var.k3s_vms :
        vm.name => {
          ansible_host = vm.ip_address
          ansible_user = var.vm_cloudinit.username
        } if vm.role == "control"
      }
    }
    k3s_workers = {
      hosts = {
        for key, vm in var.k3s_vms :
        vm.name => {
          ansible_host = vm.ip_address
          ansible_user = var.vm_cloudinit.username
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
%{for key, vm in var.k3s_vms~}
%{if vm.role == "control"~}
${vm.name} ansible_host=${vm.ip_address}
%{endif~}
%{endfor~}

[k3s_workers]
%{for key, vm in var.k3s_vms~}
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
ansible_user=${var.vm_cloudinit.username}
ansible_password=${var.vm_cloudinit.password}
EOT
}

# CONFIGURATION SUMMARY
output "cluster_summary" {
  description = "High-level cluster configuration summary"
  value = {
    total_vms       = length(var.k3s_vms)
    control_nodes   = length([for vm in var.k3s_vms : vm if vm.role == "control"])
    worker_nodes    = length([for vm in var.k3s_vms : vm if vm.role == "worker"])
    network_gateway = var.network.gateway
    storage_pool    = var.proxmox_infrastructure.storage_pool
    template_id     = var.proxmox_infrastructure.template_vm_id
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
