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

# ORGANISATION
variable "gitea_org" {
  description = "Organisation that holds the mirrors. gitea_user and the admin are both owners, so either can see and manage them"
  type        = string
}

# MIRRORS
variable "gitea_mirrors" {
  description = "Pull mirrors in gitea_org, keyed by repository name. interval uses Gitea's units (h, m, s), 0 disables syncing"
  type = map(object({
    source   = string
    interval = optional(string, "15m")
  }))
  default = {
    homelab-argocd-config = {
      source = "https://github.com/mcdermg/homelab-argocd-config.git"
    }
  }
}
