# Download file Module

Downloads files to Proxmox storage including ISOs, LXC templates, and VM disk images.

## Usage

```hcl
module "iso_downloads" {
  source = "./modules/download_file"

  content_type = "iso"
  node_name    = "pve01"
  datastore_id = "local"

  downloads = {
    debian_13 = {
      url = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
