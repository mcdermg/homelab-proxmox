output "files" {
  description = "Map of all downloaded files"
  value       = proxmox_virtual_environment_download_file.this
}

output "file_ids" {
  description = "Map of file IDs for downloaded files"
  value       = { for k, v in proxmox_virtual_environment_download_file.this : k => v.id }
}
