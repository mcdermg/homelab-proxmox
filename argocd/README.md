# argocd

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.3 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 3.3.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.argocd_root_app](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [terraform_data.argocd_admin_password](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_remote_state.gitea](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/data-sources/remote_state) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_argocd_admin_password"></a> [argocd\_admin\_password](#input\_argocd\_admin\_password) | Password for the ArgoCD admin user, stored bcrypt hashed in argocd-secret | `string` | n/a | yes |
| <a name="input_gitea_state_key"></a> [gitea\_state\_key](#input\_gitea\_state\_key) | Key of the gitea/ state in the R2 bucket, read for ArgoCD's read-only login | `string` | `"homelab/gitea/terraform.tfstate"` | no |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Kubeconfig file and context for the k3s cluster (ansible/k3s.yaml writes the k3s context) | <pre>object({<br/>    path    = string<br/>    context = string<br/>  })</pre> | <pre>{<br/>  "context": "k3s",<br/>  "path": "/home/gary/.kube/config"<br/>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
