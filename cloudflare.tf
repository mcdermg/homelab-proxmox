locals {
  tunnel_services = {
    "gatus"    = "http://192.168.0.62"
    "gitea"    = "http://${var.lxc_containers.gitea.ip_address}:80"
    "postgres" = "http://${var.lxc_containers.postgres.ip_address}:80"
    "speed"    = "http://192.168.1.111:8080"
    "k8status" = "http://192.168.1.11:80"
    "nginx"    = "http://192.168.1.12:80"
    "argocd"   = "http://192.168.1.13"
    "proxmox"  = "https://192.168.1.250:8006"
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
        for key, service in local.tunnel_services : {
          hostname = "${key}.${var.cloudflare_zone}"
          service  = service
          origin_request = key == "proxmox" ? {
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
