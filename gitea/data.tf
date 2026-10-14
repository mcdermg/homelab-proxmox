# Teams of gitea_org, to find the Owners team Gitea creates with every organisation
data "gitea_teams" "org" {
  organisation = gitea_org.this.name
}
