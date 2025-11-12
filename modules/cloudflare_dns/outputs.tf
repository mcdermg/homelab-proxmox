# output "a_record_hostnames" {
#   description = "Map of A record names to their full hostnames"
#   value = {
#     for key, record in cloudflare_record.a_records :
#     key => record.hostname
#   }
# }

output "cname_records" {
  description = "Map of CNAME records"
  value       = cloudflare_dns_record.cname_records
}

# output "a_record_ids" {
#   description = "Map of A record names to their Cloudflare record IDs"
#   value = {
#     for key, record in cloudflare_record.a_records :
#     key => record.id
#   }
# }

# output "cname_record_ids" {
#   description = "Map of CNAME record names to their Cloudflare record IDs"
#   value = {
#     for key, record in cloudflare_record.cname_records :
#     key => record.id
#   }
# }
