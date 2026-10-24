# IP ALLOWLIST FALLBACK
# LAB-133: replaced by the login policy below. Uncomment these, the allowed_ips locals and the IP policy together to go back.
# data "http" "my_ipv4" {
#   url = "https://api4.ipify.org"
#   retry {
#     attempts     = 3
#     max_delay_ms = 2000
#     min_delay_ms = 1000
#   }
#   lifecycle {
#     postcondition {
#       condition     = self.status_code == 200
#       error_message = "api4.ipify.org returned HTTP ${self.status_code}"
#     }
#   }
# }
#
# data "http" "my_ipv6" {
#   # api64 returns IPv6 if this machine has it, otherwise IPv4, so runs without IPv6 don't fail
#   url = "https://api64.ipify.org"
#   retry {
#     attempts     = 3
#     max_delay_ms = 2000
#     min_delay_ms = 1000
#   }
#   lifecycle {
#     postcondition {
#       condition     = self.status_code == 200
#       error_message = "api64.ipify.org returned HTTP ${self.status_code}"
#     }
#   }
# }

locals {
  # List preserves insertion order — new entries appended here won't reorder the tunnel ingress config
  tunnel_services_list = [
    { name = "gatus", service = "http://192.168.0.62" },
    { name = "gitea", service = "http://${var.lxc_containers.gitea.ip_address}:80" },
    # LAB-133: database admin stays LAN-only
    # { name = "postgres", service = "http://${var.lxc_containers.postgres.ip_address}:80" },
    { name = "speed", service = "http://${var.lxc_containers.librespeed.ip_address}:8080" },
    { name = "k8status", service = "http://192.168.1.11:80" },
    { name = "nginx", service = "http://192.168.1.12:80" },
    { name = "argocd", service = "http://192.168.1.13" },
    { name = "pve01", service = "https://${var.proxmox_nodes.pve01.address}:8006" },
    { name = "pulse", service = "http://${var.lxc_containers.pulse.ip_address}:7655" },
    { name = "grafana", service = "http://192.168.1.14" },
    { name = "prometheus", service = "http://192.168.1.15" },
    { name = "pve02", service = "https://${var.proxmox_nodes.pve02.address}:8006" },
    # ISP router admin page, on the house network: cloudflared reaches it through the MikroTik, like Gatus.
    # It returns 403 to any Host but its own IP, and http:// redirects to https://192.168.0.1
    { name = "isp", service = "https://192.168.0.1", host_header = "192.168.0.1" },
  ]
  # Derived map for for_each resources (DNS records, access applications) — order irrelevant there
  tunnel_services = { for item in local.tunnel_services_list : item.name => item.service }

  # LAB-136: Gatus goes behind the same login as everything else
  # public_services = toset(["gatus"])
  public_services = toset([])

  # Lab subnet (192.168.1.0/24) routed to the Cloudflare One client
  lab_cidr = "${cidrhost("${var.network.gateway}${var.network.cidr_suffix}", 0)}${var.network.cidr_suffix}"

  # Cloudflare's default client exclude list, with 192.168.0.0/16 replaced by everything in it except the lab /24
  client_split_tunnel_exclude = [
    for address in [
      "ff05::/16", "ff04::/16", "ff03::/16", "ff02::/16", "ff01::/16", "fe80::/10", "fd00::/8",
      "255.255.255.255/32", "240.0.0.0/4", "224.0.0.0/24", "192.0.0.0/24", "172.16.0.0/12",
      "169.254.0.0/16", "100.64.0.0/10", "10.0.0.0/8",
      "192.168.0.0/24", "192.168.2.0/23", "192.168.4.0/22", "192.168.8.0/21",
      "192.168.16.0/20", "192.168.32.0/19", "192.168.64.0/18", "192.168.128.0/17",
    ] : { address = address }
  ]

  # LAB-133: IP allowlist fallback, see the data sources at the top
  # ipv4_addr = chomp(data.http.my_ipv4.response_body)
  # ipv6_addr = chomp(data.http.my_ipv6.response_body)
  #
  # ipv4 = "${local.ipv4_addr}/32"
  # # cidrhost(..., 0) returns the /64 network address and handles :: shortcuts; null when no IPv6
  # ipv6        = strcontains(local.ipv6_addr, ":") ? "${cidrhost("${local.ipv6_addr}/64", 0)}/64" : null
  # allowed_ips = compact([local.ipv4, local.ipv6])
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

# EXPORTER TOKEN
# Read-only token for the cloudflare-exporter in k3s (LAB-162): zone Analytics Read and nothing else.
# Creating it needs Account API Tokens Edit on the provider's token
data "cloudflare_account_api_token_permission_groups_list" "zone_analytics_read" {
  account_id = var.cloudflare_account_id
  name       = "Analytics%20Read"
  scope      = "com.cloudflare.api.account.zone"
}

resource "cloudflare_account_token" "cloudflare_exporter" {
  account_id = var.cloudflare_account_id
  name       = "cloudflare-exporter"

  policies = [{
    effect = "allow"
    # one() fails the plan if the lookup doesn't find exactly one group
    permission_groups = [{ id = one(data.cloudflare_account_api_token_permission_groups_list.zone_analytics_read.result).id }]
    resources         = jsonencode({ "com.cloudflare.api.account.zone.${var.cloudflare_zone_id}" = "*" })
  }]
}

module "tunnel_dns_records" {
  source = "./modules/cloudflare_dns"

  zone_id = var.cloudflare_zone_id
  zone    = var.cloudflare_zone

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

  # A new hostname is only routed once its Access app exists, so it's never briefly public
  depends_on = [cloudflare_zero_trust_access_application.tunnel_services]

  config = {
    ingress = concat(
      [
        for item in local.tunnel_services_list : {
          hostname = "${item.name}.${var.cloudflare_zone}"
          service  = item.service
          # Proxmox and the ISP router serve self-signed certificates
          origin_request = startswith(item.service, "https://") ? {
            no_tls_verify    = true
            http_host_header = lookup(item, "host_header", null)
          } : null
        }
      ],
      [{
        service = "http_status:404"
      }]
    )
  }
}

# ACCESS LOGIN
# Existing org: import before the first apply (see README, Cloudflare Access)
resource "cloudflare_zero_trust_organization" "homelab" {
  account_id  = var.cloudflare_account_id
  name        = var.cloudflare_access.org_name
  auth_domain = "${var.cloudflare_access.team_name}.cloudflareaccess.com"

  # Independent MFA on every app; the enrolment page (App Launcher) stays exempt
  mfa_config = {
    allowed_authenticators = var.cloudflare_access.mfa_authenticators
    session_duration       = var.cloudflare_access.mfa_session_duration
  }
  mfa_required_for_all_apps = true

  # Current values, set so the plan doesn't clear them
  deny_unmatched_requests                     = false
  deny_unmatched_requests_exempted_zone_names = []

  # Off, as before; the API rejects the block unless all three fields are sent
  service_token_inactivity = {
    enabled                   = false
    action                    = "disable"
    inactivity_threshold_days = 30
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Log in with the Cloudflare account; only members of this account can authenticate
resource "cloudflare_zero_trust_access_identity_provider" "cloudflare" {
  account_id = var.cloudflare_account_id
  name       = "Cloudflare"
  type       = "cloudflare"
  config = {
    restrict_to_account_members = true
  }
}

# The approved account, logged in through the Cloudflare login; used by every app below
resource "cloudflare_zero_trust_access_policy" "approved_account" {
  account_id = var.cloudflare_account_id
  name       = "Allow approved account"
  decision   = "allow"
  include = [{
    email = {
      email = var.cloudflare_access.allowed_email
    }
  }]
  require = [{
    login_method = {
      id = cloudflare_zero_trust_access_identity_provider.cloudflare.id
    }
  }]
}

resource "cloudflare_zero_trust_access_application" "tunnel_services" {
  for_each = { for k, v in local.tunnel_services : k => v if !contains(local.public_services, k) }

  account_id       = var.cloudflare_account_id
  name             = "${each.key} - Homelab"
  domain           = "${each.key}.${var.cloudflare_zone}"
  type             = "self_hosted"
  session_duration = var.cloudflare_access.session_duration
  # auto_redirect_to_identity = false
  # One login method, so skip the chooser page
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.cloudflare.id]
  auto_redirect_to_identity = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.approved_account.id
    precedence = 1
  }]

  # LAB-133: IP allowlist fallback, see the data sources at the top
  # policies = [{
  #   name     = "Allow from allowed IPs"
  #   decision = "non_identity"
  #   include = [
  #     for ip_addr in local.allowed_ips : {
  #       ip = {
  #         ip = ip_addr
  #       }
  #     }
  #   ]
  # }]
}

# PRIVATE NETWORK (CLOUDFLARE ONE CLIENT)
# Lets an enrolled laptop reach the lab subnet (Proxmox API, SSH) through the tunnel from off the LAN.
# Bootstrap off-LAN with a targeted apply (see README, Cloudflare Access).
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "lab" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
  network    = local.lab_cidr
  comment    = "Lab subnet for the Cloudflare One client"
}

# Only the approved account can enrol a device
resource "cloudflare_zero_trust_access_application" "device_enrollment" {
  account_id                = var.cloudflare_account_id
  type                      = "warp"
  name                      = "Warp Login App" # Cloudflare's name for the account's single enrolment app
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.cloudflare.id]
  auto_redirect_to_identity = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.approved_account.id
    precedence = 1
  }]
}

# App Launcher (<team>.cloudflareaccess.com): where MFA devices are enrolled; off until it has a policy
resource "cloudflare_zero_trust_access_application" "app_launcher" {
  account_id                = var.cloudflare_account_id
  type                      = "app_launcher"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.cloudflare.id]
  auto_redirect_to_identity = true
  # Cloudflare's default title, set so the provider's default doesn't show as a diff on every plan
  landing_page_design = {
    title = "Welcome!"
  }

  policies = [{
    id         = cloudflare_zero_trust_access_policy.approved_account.id
    precedence = 1
  }]
}

# Client profile for the approved account: send the lab subnet through Cloudflare
resource "cloudflare_zero_trust_device_custom_profile" "lab_access" {
  account_id      = var.cloudflare_account_id
  name            = "Lab access"
  enabled         = true
  precedence      = 100
  match           = "identity.email == \"${var.cloudflare_access.allowed_email}\""
  service_mode_v2 = { mode = "warp" }
  exclude         = local.client_split_tunnel_exclude
}

# GATEWAY DNS FILTERING
# Policies apply to every query Gateway sees: the MikroTik over DoH (location below) and enrolled clients anywhere
resource "cloudflare_zero_trust_dns_location" "home" {
  account_id = var.cloudflare_account_id
  name       = "Home"
  networks   = []
  max_ttl    = { mode = "inherit" } # the default; set because the provider errors when it's unknown
  # DoH only: the IPv4 and IPv6 endpoints need a fixed source IP, which the ISP doesn't give
  # networks = [] and require_token set explicitly: the provider errors on unknown values there (5.27)
  endpoints = {
    doh  = { enabled = true, networks = [], require_token = false }
    dot  = { enabled = false, networks = [] }
    ipv4 = { enabled = false }
    ipv6 = { enabled = false, networks = [] }
  }

  # The empty lists read back as null, so they'd show as a diff on every plan (provider issue #7400)
  lifecycle {
    ignore_changes = [endpoints.doh.networks, endpoints.dot.networks, endpoints.ipv6.networks]
  }
}

resource "cloudflare_zero_trust_gateway_policy" "block_security_threats" {
  account_id  = var.cloudflare_account_id
  name        = "Block security threats"
  description = "Cloudflare's security categories (malware, phishing, C2 and so on)"
  enabled     = true
  action      = "block"
  filters     = ["dns"]
  traffic     = "any(dns.security_category[*] in {68 178 80 83 176 175 117 131 134 151 153})"
}

resource "cloudflare_zero_trust_gateway_policy" "block_ads" {
  account_id  = var.cloudflare_account_id
  name        = "Block ads"
  description = "Content category 66: Ads > Advertisements"
  enabled     = true
  action      = "block"
  filters     = ["dns"]
  traffic     = "any(dns.content_category[*] in {66})"
}
