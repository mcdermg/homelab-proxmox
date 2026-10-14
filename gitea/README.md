# gitea

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_gitea"></a> [gitea](#requirement\_gitea) | ~> 0.8 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_gitea"></a> [gitea](#provider\_gitea) | 0.8.1 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [gitea_org.this](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs/resources/org) | resource |
| [gitea_repository.mirror](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs/resources/repository) | resource |
| [gitea_team_membership.owner](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs/resources/team_membership) | resource |
| [gitea_user.owner](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs/resources/user) | resource |
| [gitea_teams.org](https://registry.terraform.io/providers/go-gitea/gitea/latest/docs/data-sources/teams) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_gitea_admin"></a> [gitea\_admin](#input\_gitea\_admin) | Gitea admin login the provider uses (the user the Ansible gitea role creates) | <pre>object({<br/>    username = string<br/>    password = string<br/>  })</pre> | n/a | yes |
| <a name="input_gitea_mirrors"></a> [gitea\_mirrors](#input\_gitea\_mirrors) | Pull mirrors in gitea\_org, keyed by repository name. interval uses Gitea's units (h, m, s), 0 disables syncing | <pre>map(object({<br/>    source   = string<br/>    interval = optional(string, "15m")<br/>  }))</pre> | <pre>{<br/>  "homelab-argocd-config": {<br/>    "source": "https://github.com/mcdermg/homelab-argocd-config.git"<br/>  }<br/>}</pre> | no |
| <a name="input_gitea_org"></a> [gitea\_org](#input\_gitea\_org) | Organisation that holds the mirrors. gitea\_user and the admin are both owners, so either can see and manage them | `string` | n/a | yes |
| <a name="input_gitea_url"></a> [gitea\_url](#input\_gitea\_url) | Gitea base URL (the gitea container from the root config) | `string` | n/a | yes |
| <a name="input_gitea_user"></a> [gitea\_user](#input\_gitea\_user) | Gitea user added to gitea\_org's Owners team. Gitea needs a unique email per user, so it can't reuse the admin's | <pre>object({<br/>    username = string<br/>    email    = string<br/>    password = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_mirror_clone_urls"></a> [mirror\_clone\_urls](#output\_mirror\_clone\_urls) | HTTP clone URL of each mirror, for ArgoCD |
<!-- END_TF_DOCS -->
