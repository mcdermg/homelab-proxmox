# Cloudflare DNS Module

This module manages Cloudflare DNS records (A and CNAME) in a flexible, reusable way.

## Features

- Create multiple A records with a single module call
- Create multiple CNAME records with a single module call
- Support for proxied (orange cloud) and DNS-only (grey cloud) records
- Customizable TTL values
- Optional comments for each record

## Usage

```hcl
module "cloudflare_dns" {
  source = "./modules/cloudflare_dns"

  zone_id = var.cloudflare_zone_id

  # A Records - point to IP addresses
  a_records = {
    "caddy.lab" = {
      ip_address = "192.168.1.100"
      comment    = "Caddy reverse proxy"
    }
    "*.lab" = {
      ip_address = "192.168.1.100"
      comment    = "Wildcard for lab services"
    }
  }

  # CNAME Records - point to other domains
  cname_records = {
    "grafana" = {
      target  = "tunnel-id.cfargotunnel.com"
      proxied = true
      comment = "Grafana via Cloudflare Tunnel"
    }
  }
}
```

## Input Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| zone_id | Cloudflare Zone ID | `string` | n/a | yes |
| a_records | Map of A records to create | `map(object)` | `{}` | no |
| cname_records | Map of CNAME records to create | `map(object)` | `{}` | no |

### A Record Object

```hcl
{
  ip_address = string              # Required
  ttl        = number               # Optional, default: 1 (Auto)
  proxied    = bool                 # Optional, default: false
  comment    = string               # Optional, default: "Managed by Terraform"
}
```

### CNAME Record Object

```hcl
{
  target  = string                  # Required
  ttl     = number                  # Optional, default: 1 (Auto)
  proxied = bool                    # Optional, default: false
  comment = string                  # Optional, default: "Managed by Terraform"
}
```

## Outputs

| Name | Description |
|------|-------------|
| a_record_hostnames | Map of A record names to full hostnames |
| cname_record_hostnames | Map of CNAME record names to full hostnames |
| a_record_ids | Map of A record names to Cloudflare IDs |
| cname_record_ids | Map of CNAME record names to Cloudflare IDs |

## Examples

### Internal Services (DNS-only)

```hcl
a_records = {
  "grafana.lab" = {
    ip_address = "192.168.1.100"
    proxied    = false  # DNS-only for internal
  }
  "prometheus.lab" = {
    ip_address = "192.168.1.100"
    proxied    = false
  }
}
```

### External Services (Proxied)

```hcl
cname_records = {
  "app" = {
    target  = "tunnel-abc123.cfargotunnel.com"
    proxied = true  # Enable Cloudflare proxy
  }
}
```

### Wildcard Records

```hcl
a_records = {
  "*.services" = {
    ip_address = "192.168.1.100"
    comment    = "Wildcard for all services subdomain"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.13 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | 5.19.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [cloudflare_dns_record.a_records](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_record.cname_records](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_a_records"></a> [a\_records](#input\_a\_records) | Map of A records to create. Key is the record name, value contains ip\_address and optional ttl, proxied, comment | <pre>map(object({<br>    ip_address = string<br>    ttl        = optional(number, 1)   # 1 = Auto<br>    proxied    = optional(bool, false) # false = DNS only, true = proxied<br>    comment    = optional(string, "Managed by Terraform")<br>  }))</pre> | `{}` | no |
| <a name="input_cname_records"></a> [cname\_records](#input\_cname\_records) | Map of CNAME records to create. Key is the record name, value contains target and optional ttl, proxied, comment | <pre>map(object({<br>    target  = string<br>    ttl     = optional(number, 1)   # 1 = Auto<br>    proxied = optional(bool, false) # false = DNS only, true = proxied<br>    comment = optional(string, "Managed by Terraform")<br>  }))</pre> | `{}` | no |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare Zone ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cname_records"></a> [cname\_records](#output\_cname\_records) | Map of CNAME records |
<!-- END_TF_DOCS -->
