output "mirror_clone_urls" {
  description = "HTTP clone URL of each mirror, for ArgoCD"
  value       = { for name, repo in gitea_repository.mirror : name => repo.clone_url }
}
