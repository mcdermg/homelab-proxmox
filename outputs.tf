# DNS
output "dns_records" {
  description = "Public hostname of each service behind the Cloudflare tunnel, and the origin the tunnel sends it to"
  value = {
    for name, service in local.tunnel_services :
    "${name}.${var.cloudflare_zone}" => service
  }
}

# GATEWAY DNS
output "gateway_doh_url" {
  description = "DoH URL of the Home Gateway DNS location; set as dns_doh_server in mikrotik-hapac2"
  value       = "https://${cloudflare_zero_trust_dns_location.home.doh_subdomain}.cloudflare-gateway.com/dns-query"
}
