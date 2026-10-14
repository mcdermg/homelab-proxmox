# Same R2 bucket as the root config, separate state. Credentials come from the root .envrc
terraform {
  backend "s3" {
    bucket       = "iac-state"
    key          = "homelab/gitea/terraform.tfstate"
    region       = "auto"
    use_lockfile = true

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
