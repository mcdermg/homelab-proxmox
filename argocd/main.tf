# Runs after gitea/: ArgoCD pulls its Applications from the private Gitea mirror.
# OpenTofu owns the ArgoCD install; ArgoCD owns everything it deploys into the cluster.

locals {
  argocd_login = data.terraform_remote_state.gitea.outputs.argocd_repo_credentials
}

# ARGOCD
# bcrypt() salts a new hash on every run, so the hash is stored once and only replaced when the password changes.
# The mtime is stored with it: the chart defaults it to now, which would log everyone out on every upgrade
resource "terraform_data" "argocd_admin_password" {
  input = {
    hash  = bcrypt(var.argocd_admin_password)
    mtime = timestamp()
  }
  triggers_replace = [sha256(var.argocd_admin_password)]

  lifecycle {
    ignore_changes = [input]
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.10.3"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600 # first install pulls the images on every node, which took over 3 minutes

  values = [
    file("${path.module}/values/argo-cd.yaml"),
  ]

  set_sensitive = [
    {
      name  = "configs.credentialTemplates.gitea.username"
      value = local.argocd_login.username
    },
    {
      name  = "configs.credentialTemplates.gitea.password"
      value = local.argocd_login.password
    },
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = terraform_data.argocd_admin_password.output.hash
    },
    {
      name  = "configs.secret.argocdServerAdminPasswordMtime"
      value = terraform_data.argocd_admin_password.output.mtime
    },
  ]
}

# ROOT APPLICATION (app of apps)
# A chart rather than kubernetes_manifest: the Application CRD only exists once argo-cd is installed,
# and kubernetes_manifest needs it at plan time
resource "helm_release" "argocd_root_app" {
  name       = "argocd-root-app"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.6"
  namespace  = helm_release.argocd.namespace

  values = [
    file("${path.module}/values/root-app.yaml"),
  ]
}
