# GITEA CONNECTION
variable "gitea_url" {
  description = "Gitea base URL (the gitea container from the root config)"
  type        = string
}

variable "gitea_admin" {
  description = "Gitea admin login the provider uses (the user the Ansible gitea role creates)"
  type = object({
    username = string
    password = string
  })
  sensitive = true
}

# USER
variable "gitea_user" {
  description = "Gitea user added to gitea_org's Owners team. Gitea needs a unique email per user, so it can't reuse the admin's"
  type = object({
    username = string
    email    = string
    password = string
  })
  sensitive = true
}

variable "gitea_argocd_user" {
  description = "Read-only Gitea user ArgoCD pulls the mirrors with. Its email must also be unique"
  type = object({
    username = string
    email    = string
    password = string
  })
  sensitive = true
}

# ORGANISATION
variable "gitea_org" {
  description = "Organisation that holds the mirrors. gitea_user and the admin are both owners, so either can see and manage them"
  type        = string
}

# MIRRORS
variable "gitea_mirrors" {
  description = "Private pull mirrors in gitea_org, readable by gitea_argocd_user, keyed by repository name. interval in the form Gitea returns it (e.g. 15m0s, 8h0m0s, or it shows a diff every plan), 0 disables syncing"
  type = map(object({
    source   = string
    interval = optional(string, "10m0s")
  }))
  default = {
    homelab-argocd-config = {
      source = "https://github.com/mcdermg/homelab-argocd-config.git"
    }
  }
}
