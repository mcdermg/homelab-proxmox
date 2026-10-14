# DNS
output "dns_records" {
  description = "Public hostname of each service behind the Cloudflare tunnel, and the origin the tunnel sends it to"
  value = {
    for name, service in local.tunnel_services :
    "${name}.${var.cloudflare_zone}" => service
  }
}
