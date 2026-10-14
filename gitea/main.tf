# Runs after the root config and the Ansible playbook: the provider needs Gitea up, so this has its own state

# USER
resource "gitea_user" "owner" {
  username             = var.gitea_user.username
  login_name           = var.gitea_user.username
  email                = var.gitea_user.email
  password             = var.gitea_user.password
  must_change_password = false
}

# Read-only login ArgoCD pulls the mirrors with
resource "gitea_user" "argocd" {
  username             = var.gitea_argocd_user.username
  login_name           = var.gitea_argocd_user.username
  email                = var.gitea_argocd_user.email
  password             = var.gitea_argocd_user.password
  must_change_password = false
}

# ORGANISATION
# The API user (the admin) creates it and so joins its Owners team; gitea_user is added to Owners too
resource "gitea_org" "this" {
  name       = var.gitea_org
  visibility = "public"
}

resource "gitea_team_membership" "owner" {
  team_id  = one([for team in data.gitea_teams.org.teams : team.id if team.name == "Owners"])
  username = gitea_user.owner.username
}

# MIRRORS
# Private pull mirrors: only org owners and the ArgoCD user can read them
resource "gitea_repository" "mirror" {
  for_each = var.gitea_mirrors

  username                  = gitea_org.this.name
  name                      = each.key
  private                   = true
  mirror                    = true
  migration_service         = "git"
  migration_clone_address   = each.value.source
  migration_mirror_interval = each.value.interval
}

# ArgoCD gets read access per mirror as a collaborator, not through a read-only team: provider 0.8 can't
# manage non-admin teams (gitea.com terraform-provider-gitea issues #194 and #135)
resource "gitea_repository_collaborator" "argocd" {
  for_each = gitea_repository.mirror

  owner      = gitea_org.this.name
  repo       = each.value.name
  username   = gitea_user.argocd.username
  permission = "read"
}
