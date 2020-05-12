variable "api_key" {
  type = string
}
variable "project_id" {
  type = string
}

variable "name" {
  type    = string
  default = "tf-module-test"
}

output "IP_Address" {
  value = packet_device.my_tf_server.access_public_ipv4
}
