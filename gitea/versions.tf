# OpenTofu ignores required_version, so the version is pinned here
language {
  compatible_with {
    opentofu = "~> 1.12"
  }
}

terraform {
  required_providers {
    gitea = {
      source  = "go-gitea/gitea"
      version = "~> 0.8"
    }
  }
}

provider "gitea" {
  base_url = var.gitea_url
  username = var.gitea_admin.username
  password = var.gitea_admin.password
}
