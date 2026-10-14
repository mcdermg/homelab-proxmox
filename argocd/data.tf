# gitea/ state: ArgoCD's read-only login, so the password lives only in gitea/terraform.tfvars
data "terraform_remote_state" "gitea" {
  backend = "s3"
  config = {
    bucket = "iac-state"
    key    = var.gitea_state_key
    region = "auto"

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
