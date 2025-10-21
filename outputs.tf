## VM IDENTIFICATION OUTPUTS
#output "vm_ids" {
#  description = "Map of VM names to their VM IDs"
#  value       = module.k3s_cluster.vm_ids
#}
#
#output "vm_names" {
#  description = "List of all VM names"
#  value       = module.k3s_cluster.vm_names
#}
#
## NETWORK OUTPUTS
#output "vm_ip_addresses" {
#  description = "Map of VM names to their IP addresses"
#  value       = module.k3s_cluster.vm_ip_addresses
#}
#
#output "vm_network_details" {
#  description = "Complete network configuration for all VMs"
#  value       = module.k3s_cluster.vm_network_details
#}
#
## ROLE-BASED OUTPUTS
#output "control_plane_ips" {
#  description = "IP addresses of control plane nodes"
#  value       = module.k3s_cluster.control_plane_ips
#}
#
#output "worker_node_ips" {
#  description = "IP addresses of worker nodes"
#  value       = module.k3s_cluster.worker_node_ips
#}
#
## ANSIBLE INVENTORY OUTPUTS
#output "ansible_inventory_json" {
#  description = "Ansible inventory in JSON format"
#  sensitive   = true
#  value       = module.k3s_cluster.ansible_inventory_json
#}
#
#output "ansible_inventory_ini" {
#  description = "Ansible inventory in INI format"
#  sensitive   = true
#  value       = module.k3s_cluster.ansible_inventory_ini
#}
#
## CONFIGURATION SUMMARY
#output "cluster_summary" {
#  description = "High-level cluster configuration summary"
#  value       = module.k3s_cluster.cluster_summary
#}
#
## VM RESOURCE DETAILS
#output "vm_mac_addresses" {
#  description = "MAC addresses of VM network interfaces"
#  value       = module.k3s_cluster.vm_mac_addresses
#}
#
#output "vm_ipv4_addresses" {
#  description = "IPv4 addresses reported by QEMU agent"
#  value       = module.k3s_cluster.vm_ipv4_addresses
#}
#
