resource "cloudflare_record" "a_record" {
  count = length(var.ip_addresses)
  zone_id = var.cloudflare_zone_id
  name = var.dns_name
  value = var.ip_addresses[count.index]
  type = "A"
}
