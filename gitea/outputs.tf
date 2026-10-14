output "mirror_clone_urls" {
  description = "HTTP clone URL of each mirror, for ArgoCD"
  value       = { for name, repo in gitea_repository.mirror : name => repo.clone_url }
}

output "argocd_repo_credentials" {
  description = "Read-only login ArgoCD uses for the repos in gitea_org (read by argocd/)"
  value = {
    username = gitea_user.argocd.username
    password = var.gitea_argocd_user.password
  }
  sensitive = true
}
