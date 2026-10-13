variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "zone" {
  description = "Cloudflare zone name, appended to each record key to form the FQDN"
  type        = string
}

variable "a_records" {
  description = "Map of A records to create. Key is the record name, value contains ip_address and optional ttl, proxied, comment"
  type = map(object({
    ip_address = string
    ttl        = optional(number, 1)   # 1 = Auto
    proxied    = optional(bool, false) # false = DNS only, true = proxied
    comment    = optional(string, "Managed by Terraform")
  }))
  default = {}
}

variable "cname_records" {
  description = "Map of CNAME records to create. Key is the record name, value contains target and optional ttl, proxied, comment"
  type = map(object({
    target  = string
    ttl     = optional(number, 1)   # 1 = Auto
    proxied = optional(bool, false) # false = DNS only, true = proxied
    comment = optional(string, "Managed by Terraform")
  }))
  default = {}
}
