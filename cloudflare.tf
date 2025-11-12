locals {
  tunnel_services = {
    #"grafana"    = "http://${var.lxc_containers.caddy.ip_address}:80"
    #"prometheus" = "http://${var.lxc_containers.caddy.ip_address}:80"
    "gitea"    = "http://${var.lxc_containers.gitea.ip_address}:3000"
    "postgres" = "http://${var.lxc_containers.postgres.ip_address}:5432"
  }
}

resource "random_id" "cloudflared_tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id    = var.cloudflare_account_id
  name          = "homelab-tunnel"
  tunnel_secret = random_id.cloudflared_tunnel_secret.b64_std
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
        for key, service in local.tunnel_services : {
          hostname = "${key}.${var.cloudflare_zone}"
          service  = service
        }
      ],
      [{
        service = "http_status:404"
      }]
    )
  }
}
