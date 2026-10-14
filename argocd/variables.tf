# CLUSTER
variable "kubeconfig" {
  description = "Kubeconfig file and context for the k3s cluster (ansible/k3s.yaml writes the k3s context)"
  type = object({
    path    = string
    context = string
  })
  default = {
    path    = "/home/gary/.kube/config"
    context = "k3s"
  }
}

# GITEA
variable "gitea_state_key" {
  description = "Key of the gitea/ state in the R2 bucket, read for ArgoCD's read-only login"
  type        = string
  default     = "homelab/gitea/terraform.tfstate"
}

# ARGOCD
variable "argocd_admin_password" {
  description = "Password for the ArgoCD admin user, stored bcrypt hashed in argocd-secret"
  type        = string
  sensitive   = true
}
