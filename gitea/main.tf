# Runs after the root config and the Ansible playbook: the provider needs Gitea up, so this has its own state

# USER
resource "gitea_user" "owner" {
  username             = var.gitea_user.username
  login_name           = var.gitea_user.username
  email                = var.gitea_user.email
  password             = var.gitea_user.password
  must_change_password = false
}

# ORGANISATION
# Public so its public repos can be read without logging in. The API user (the admin) creates it and
# so joins its Owners team; gitea_user is added to Owners too
resource "gitea_org" "this" {
  name       = var.gitea_org
  visibility = "public"
}

resource "gitea_team_membership" "owner" {
  team_id  = one([for team in data.gitea_teams.org.teams : team.id if team.name == "Owners"])
  username = gitea_user.owner.username
}

# MIRRORS
# Public pull mirrors: ArgoCD reads them without credentials
resource "gitea_repository" "mirror" {
  for_each = var.gitea_mirrors

  username                  = gitea_org.this.name
  name                      = each.key
  private                   = false
  mirror                    = true
  migration_service         = "git"
  migration_clone_address   = each.value.source
  migration_mirror_interval = each.value.interval
}
