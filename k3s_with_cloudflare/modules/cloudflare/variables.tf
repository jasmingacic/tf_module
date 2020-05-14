variable "cloudflare_email" {
    type = string
    description = "EMail address used for cloudflare authentication"
}

variable "cloudflare_api_key" {
    type = string
    description = "API key used for cloudflare authentication"
}

variable "cloudflare_zone_id" {
    type = string
    description = "Zone ID to create DNS record for"
}

variable "dns_name" {
    type = string
    description = "DNS name to create"
}

variable "ip_addresses" {
    type = list
    description = "IP Addresses to assign to A record"
}
