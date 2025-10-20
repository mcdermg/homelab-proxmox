# download_file Module

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

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `content_type` | Content type: `iso`, `vztmpl`, or `import` | `string` | yes |
| `node_name` | Proxmox node name | `string` | yes |
| `datastore_id` | Datastore ID for file storage | `string` | yes |
| `downloads` | Map of files to download | `map(object)` | no |

## Downloads Object

| Field | Description | Type | Default |
|-------|-------------|------|---------|
| `url` | Download URL | `string` | required |
| `file_name` | Custom filename | `string` | auto-detected |
| `checksum` | File checksum | `string` | `null` |
| `checksum_algorithm` | Algorithm: md5, sha1, sha256, etc. | `string` | `null` |
| `decompression_algorithm` | Algorithm: gz, lzo, zst, bz2 | `string` | `null` |
| `verify` | Verify checksum | `bool` | `true` |
| `overwrite` | Overwrite existing files | `bool` | `true` |
| `overwrite_unmanaged` | Overwrite unmanaged files | `bool` | `false` |
| `upload_timeout` | Upload timeout in seconds | `number` | `1800` |

## Outputs

| Name | Description |
|------|-------------|
| `files` | Map of all downloaded file resources |
| `file_ids` | Map of file IDs |

## Examples

### ISO Downloads
```hcl
module "iso_downloads" {
  source = "./modules/download_file"

  content_type = "iso"
  node_name    = "pve01"
  datastore_id = "local"

  downloads = {
    ubuntu = {
      url = "https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso"
    }
  }
}
```

### LXC Templates
```hcl
module "lxc_downloads" {
  source = "./modules/download_file"

  content_type = "vztmpl"
  node_name    = "pve01"
  datastore_id = "local"

  downloads = {
    alpine = {
      url = "http://download.proxmox.com/images/system/alpine-3.22-default_20250617_amd64.tar.xz"
    }
  }
}
```

### Disable Downloads
Set `downloads = {}` to skip all downloads for a module instance.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 0.85.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_download_file.this](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_download_file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_content_type"></a> [content\_type](#input\_content\_type) | The type of content to download: 'iso', 'vztmpl', or 'import' | `string` | n/a | yes |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | The ID of the datastore where files will be stored | `string` | n/a | yes |
| <a name="input_downloads"></a> [downloads](#input\_downloads) | Files to download to Proxmox storage | <pre>map(object({<br>    url                     = string<br>    file_name               = optional(string)<br>    checksum                = optional(string)<br>    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"<br>    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2" (only for vztmpl and import)<br>    verify                  = optional(bool, true)<br>    overwrite               = optional(bool, true)<br>    overwrite_unmanaged     = optional(bool, false)<br>    upload_timeout          = optional(number, 1800)<br>  }))</pre> | `{}` | no |
| <a name="input_node_name"></a> [node\_name](#input\_node\_name) | The name of the Proxmox node where files will be downloaded | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_file_ids"></a> [file\_ids](#output\_file\_ids) | Map of file IDs for downloaded files |
| <a name="output_files"></a> [files](#output\_files) | Map of all downloaded files |
<!-- END_TF_DOCS -->
