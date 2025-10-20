variable "content_type" {
  description = "The type of content to download: 'iso', 'vztmpl', or 'import'"
  type        = string
  validation {
    condition     = contains(["iso", "vztmpl", "import"], var.content_type)
    error_message = "content_type must be one of: 'iso', 'vztmpl', or 'import'"
  }
}

variable "node_name" {
  description = "The name of the Proxmox node where files will be downloaded"
  type        = string
}

variable "datastore_id" {
  description = "The ID of the datastore where files will be stored"
  type        = string
}

variable "downloads" {
  description = "Files to download to Proxmox storage"
  type = map(object({
    url                     = string
    file_name               = optional(string)
    checksum                = optional(string)
    checksum_algorithm      = optional(string) # "md5", "sha1", "sha224", "sha256", "sha384", "sha512"
    decompression_algorithm = optional(string) # "gz", "lzo", "zst", "bz2" (only for vztmpl and import)
    verify                  = optional(bool, true)
    overwrite               = optional(bool, true)
    overwrite_unmanaged     = optional(bool, false)
    upload_timeout          = optional(number, 1800)
  }))
  default = {}
}
