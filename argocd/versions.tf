# OpenTofu ignores required_version, so the version is pinned here
language {
  compatible_with {
    opentofu = "~> 1.12"
  }
}

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

# The kubeconfig context ansible/k3s.yaml merges into the local kubeconfig
provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig.path
    config_context = var.kubeconfig.context
  }
}
