resource "cloudflare_dns_record" "a_records" {
  for_each = var.a_records

  zone_id = var.zone_id
  name    = each.key
  content = each.value.ip_address
  type    = "A"
  ttl     = try(each.value.ttl, 1) # 1 = Auto
  proxied = try(each.value.proxied, false)
  comment = try(each.value.comment, "Managed by Terraform")
}

resource "cloudflare_dns_record" "cname_records" {
  for_each = var.cname_records

  zone_id = var.zone_id
  name    = each.key
  content = each.value.target
  type    = "CNAME"
  ttl     = try(each.value.ttl, 1) # 1 = Auto
  proxied = try(each.value.proxied, false)
  comment = try(each.value.comment, "Managed by Terraform")
}
