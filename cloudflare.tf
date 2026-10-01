data "http" "my_ipv4" {
  url = "https://api4.ipify.org"
  retry {
    attempts     = 3
    max_delay_ms = 2000
    min_delay_ms = 1000
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "api4.ipify.org returned HTTP ${self.status_code}"
    }
  }
}

data "http" "my_ipv6" {
  # api64 returns IPv6 if this machine has it, otherwise IPv4, so runs without IPv6 don't fail
  url = "https://api64.ipify.org"
  retry {
    attempts     = 3
    max_delay_ms = 2000
    min_delay_ms = 1000
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "api64.ipify.org returned HTTP ${self.status_code}"
    }
  }
}

locals {
  # List preserves insertion order — new entries appended here won't reorder the tunnel ingress config
  tunnel_services_list = [
    { name = "gatus", service = "http://192.168.0.62" },
    { name = "gitea", service = "http://${var.lxc_containers.gitea.ip_address}:80" },
    { name = "postgres", service = "http://${var.lxc_containers.postgres.ip_address}:80" },
    { name = "speed", service = "http://192.168.1.111:8080" },
    { name = "k8status", service = "http://192.168.1.11:80" },
    { name = "nginx", service = "http://192.168.1.12:80" },
    { name = "argocd", service = "http://192.168.1.13" },
    { name = "proxmox", service = "https://192.168.1.250:8006" },
    { name = "pulse", service = "http://192.168.1.112:7655" },
    { name = "grafana", service = "http://192.168.1.14" },
    { name = "prometheus", service = "http://192.168.1.15" },
  ]
  # Derived map for for_each resources (DNS records, access applications) — order irrelevant there
  tunnel_services = { for item in local.tunnel_services_list : item.name => item.service }

  public_services = toset(["gatus"])

  ipv4_addr = chomp(data.http.my_ipv4.response_body)
  ipv6_addr = chomp(data.http.my_ipv6.response_body)

  ipv4 = "${local.ipv4_addr}/32"
  # cidrhost(..., 0) returns the /64 network address and handles :: shortcuts; null when no IPv6
  ipv6        = strcontains(local.ipv6_addr, ":") ? "${cidrhost("${local.ipv6_addr}/64", 0)}/64" : null
  allowed_ips = compact([local.ipv4, local.ipv6])
}

resource "random_id" "cloudflared_tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = "homelab-tunnel"
  tunnel_secret = random_id.cloudflared_tunnel_secret.b64_std
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

module "tunnel_dns_records" {
  source = "./modules/cloudflare_dns"

  zone_id = var.cloudflare_zone_id

  cname_records = {
    for key, service in local.tunnel_services : key => {
      target  = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
      proxied = true
      comment = "Tunnel route"
    }
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  account_id = var.cloudflare_account_id

  config = {
    ingress = concat(
      [
        for item in local.tunnel_services_list : {
          hostname = "${item.name}.${var.cloudflare_zone}"
          service  = item.service
          origin_request = item.name == "proxmox" ? {
            no_tls_verify = true
          } : null
        }
      ],
      [{
        service = "http_status:404"
      }]
    )
  }
}

resource "cloudflare_zero_trust_access_application" "tunnel_services" {
  for_each = { for k, v in local.tunnel_services : k => v if !contains(local.public_services, k) }

  account_id                = var.cloudflare_account_id
  name                      = "${each.key} - Homelab"
  domain                    = "${each.key}.${var.cloudflare_zone}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false

  policies = [{
    name     = "Allow from allowed IPs"
    decision = "non_identity"
    include = [
      for ip_addr in local.allowed_ips : {
        ip = {
          ip = ip_addr
        }
      }
    ]
  }]
}
